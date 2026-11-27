# Users, groups and the Nix daemon's trust boundary.
#
# Root is locked (ADR-0007). Privilege is reached through the operator user's wheel
# membership and sudo, never by logging in as root. The recovery paths for a host whose
# sudo is broken are in docs/adr/0007-fleet-security-baseline.md, "Recovery".
#
# The operator user stays in nix.settings.trusted-users by default, because two fleet paths
# need it today:
#   - deploy-rs (flake.nix mkDeployNode) connects as the operator and copies the system
#     closure with `nix copy --no-check-sigs`. The daemon honours that flag for trusted
#     users only, and paths built on the deploying host carry no signature.
#   - the remote builder (features/fleet/nix-remote-builder-*) connects as the operator,
#     and the daemon refuses to build input-addressed derivations for untrusted users.
# Taking the operator out of trusted-users without signed store paths breaks both. The
# off-by-default `features.hardening.storeSigning` below is the way out. The operator turns
# it on once the signing keys exist on every host; it has to come first.
{
  config,
  lib,
  pkgs,
  settings,
  ...
}: let
  cfg = config.features.hardening;
  user = settings.username;
  voltaic = import ./voltaic.nix;

  # Hash of "test". It only applies when the account is first created (mutableUsers keeps an
  # existing /etc/shadow entry), so on an installed host it is long gone. Kept for fresh
  # installs, where the first login is expected to run `passwd`. See ADR-0007.
  initialOperatorHash = "$6$jne0QlJa/oBzEapq$4/gnXjNpggz.R45ND4QYwzqOyIz9CeblnqKzfnN7njIuKZSEfweNISngx87xy6VA0bEmncyyTmiNa5Q5GXDj5/";

  # Locks root, once, and only while the operator still has a password to sudo with. Shared
  # by the activation snippet (perl user management) and the unit that follows userborn.
  # Does nothing until /etc/shadow exists: under userborn a fresh boot activates before
  # userborn.service has written it, and lock-root-password.service covers that case.
  lockRootScript = ''
    if [ -e /etc/shadow ]; then
      root_hash="$(${pkgs.gawk}/bin/awk -F: '$1 == "root" { print $2 }' /etc/shadow)"
      operator_hash="$(${pkgs.gawk}/bin/awk -F: -v u=${lib.escapeShellArg user} '$1 == u { print $2 }' /etc/shadow)"
      case "$root_hash" in
        '!'* | '*'*) ;; # already locked
        *)
          case "$operator_hash" in
            '$'*)
              ${pkgs.shadow}/bin/usermod -L root
              echo "lockRootPassword: locked the root password (reverse with: passwd -u root)"
              ;;
            *)
              echo "lockRootPassword: WARNING: not locking root, because ${user} has no usable password hash, so sudo would be the only way in" >&2
              ;;
          esac
          ;;
      esac
    fi
  '';
in {
  options.features.nixos.users.userborn.enable = lib.mkEnableOption ''
    userborn (services.userborn) in place of update-users-groups.pl for /etc/passwd, group
    and shadow. Off by default and enabled on no host: measured by ./test.nix (GH-187); the
    switch-over and the rollback are in docs/runbooks/userborn.md'';

  options.features.hardening = {
    lockRoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Lock the root account's password, so nobody can log in as root, or `su` to it, with
        a password.

        Declares `users.users.root.hashedPassword = "!"`, which covers new installs and hosts
        with `users.mutableUsers = false`. With mutable users (the fleet default) NixOS never
        rewrites an existing /etc/shadow entry, so an activation script also runs
        `usermod -L root`. That prefixes the stored hash with "!", which `passwd -u root`
        reverses.

        The activation script will not lock root unless the operator account has a real
        password hash, which is what keeps the wheel/sudo path open. If it refuses, it warns
        and leaves root alone.
      '';
    };

    operatorTrusted = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the operator user is in `nix.settings.trusted-users`. A trusted user is
        root-equivalent, because it can put unsigned paths in the store that root then runs.

        Defaults to true, because deploy-rs and the remote builder both depend on it (see
        this file's header). Setting it to false needs `storeSigning.enable`, which an
        assertion checks. On a host that serves remote builds it also needs the builder
        clients to stop connecting as the operator (follow-up: `nix.sshServe` in
        features/fleet).
      '';
    };

    storeSigning = {
      enable = lib.mkEnableOption ''
        signing every locally built store path with this host's key, and trusting the
        fleet's keys. Off by default, because the keys are provisioned out of band (see
        ADR-0007, "Runbook: store-path signing")'';

      secretKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/nix-signing/secret-key";
        description = ''
          Path to this host's Nix signing key (`nix key generate-secret`). A string, not a
          path, so the key never gets copied into the world-readable store.
        '';
      };

      publicKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["drakkar-1:AAAA…="];
        description = ''
          Public halves of every fleet host's signing key. They get added to
          `nix.settings.trusted-public-keys`, so a path signed by any fleet host is accepted
          without the sender being a trusted user.
        '';
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.operatorTrusted || cfg.storeSigning.enable;
        message = ''
          features.hardening.operatorTrusted = false needs features.hardening.storeSigning.enable.
          Without signed store paths, deploy-rs (nix copy --no-check-sigs) and remote builds
          stop working once the operator is no longer a trusted user. See ADR-0007.
        '';
      }
      {
        assertion = !cfg.storeSigning.enable || cfg.storeSigning.publicKeys != [];
        message = ''
          features.hardening.storeSigning.enable is set but publicKeys is empty. List the
          public key of every fleet host (including this one) so paths they sign are accepted.
        '';
      }
    ];

    nix = {
      settings =
        {
          allowed-users = ["@wheel"];
          trusted-users = ["root"] ++ lib.optional cfg.operatorTrusted user;
        }
        // lib.optionalAttrs cfg.storeSigning.enable {
          secret-key-files = [cfg.storeSigning.secretKeyFile];
          trusted-public-keys = cfg.storeSigning.publicKeys;
        };
    };

    # The records are Voltaic's (#457, rust/tools/nixos-users): the data and games gids,
    # root's lock, and the operator's account (isNormalUser, uid, extraGroups). The parts
    # that come from the host settings stay here. uid 1000 and gid 1111 are pinned, not
    # allocated: NFS (sec=sys) authorises by number, so a client's ids must equal mimir's
    # for /data ownership to mean the same user on both ends.
    users = lib.mkMerge [
      voltaic.fragments.users
      # "!" is never a valid crypt(3) hash, so no password matches it. This replaces the
      # old initialHashedPassword, which was the hash of "test".
      (lib.mkIf cfg.lockRoot voltaic.fragments.root)
      {
        groups = {
          data.members = [user];
          games.members = [user];
        };
        users.${user} =
          voltaic.operator
          // {
            home = settings.userdir;
            description = settings.userfullname;
            # Initial password is "test". Change it on first login. See initialOperatorHash.
            initialHashedPassword = lib.mkForce initialOperatorHash;
          };
      }
    ];

    # Mutable users keep an existing shadow entry, so declaring the hash above does not lock
    # an already-installed host's root. This does, once, and only while the operator still
    # has a password to sudo with.
    system.activationScripts.lockRootPassword = lib.mkIf cfg.lockRoot {
      deps = ["users"];
      text = lockRootScript;
    };

    services.userborn.enable = config.features.nixos.users.userborn.enable;

    # Under userborn the files are written by userborn.service, which on boot runs after the
    # activation snippets, so on a fresh install the snippet above finds no /etc/shadow. This
    # runs the same lock once userborn has written the files.
    systemd.services.lock-root-password = lib.mkIf (cfg.lockRoot && config.features.nixos.users.userborn.enable) {
      description = "Lock the root password (ADR-0007)";
      after = ["userborn.service"];
      requires = ["userborn.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lockRootScript;
    };

    systemd = {
      tmpfiles = {
        rules = [
          # This creates a directory owned by root and with the group set to games
          # that is readable and writable by the members of the games group.
          "d /games 0770 root games - -"
        ];
      };
    };
  };
}
