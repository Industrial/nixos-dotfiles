# Users, groups and the Nix daemon's trust boundary.
#
# Root is locked (ADR-0006). Privilege is reached through the operator user's wheel
# membership and sudo, never by logging in as root. The recovery paths for a host whose
# sudo is broken are in docs/adr/0006-fleet-security-baseline.md, "Recovery".
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

  # Hash of "test". It only applies when the account is first created (mutableUsers keeps an
  # existing /etc/shadow entry), so on an installed host it is long gone. Kept for fresh
  # installs, where the first login is expected to run `passwd`. See ADR-0006.
  initialOperatorHash = "$6$jne0QlJa/oBzEapq$4/gnXjNpggz.R45ND4QYwzqOyIz9CeblnqKzfnN7njIuKZSEfweNISngx87xy6VA0bEmncyyTmiNa5Q5GXDj5/";
in {
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
        ADR-0006, "Runbook: store-path signing")'';

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
          stop working once the operator is no longer a trusted user. See ADR-0006.
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

    users = {
      groups = {
        data = {
          gid = 1111;
          members = [user];
        };
        games = {
          gid = 1112;
          members = [user];
        };
      };
      users = {
        root = lib.mkIf cfg.lockRoot {
          # "!" is never a valid crypt(3) hash, so no password matches it. This replaces the
          # old initialHashedPassword, which was the hash of "test".
          hashedPassword = "!";
        };

        ${user} = {
          isNormalUser = true;
          # Pinned, not allocated: NFS (sec=sys) authorises by number, so a client's uid must
          # equal mimir's for /data ownership to mean the same user on both ends.
          uid = 1000;
          home = settings.userdir;
          description = settings.userfullname;
          extraGroups = [
            "audio"
            "networkmanager"
            "plugdev"
            "render"
            "video"
            "wheel"
            "data"
            "games"
          ];
          # Initial password is "test". Change it on first login. See initialOperatorHash.
          initialHashedPassword = lib.mkForce initialOperatorHash;
        };
      };
    };

    # Mutable users keep an existing shadow entry, so declaring the hash above does not lock
    # an already-installed host's root. This does, once, and only while the operator still
    # has a password to sudo with.
    system.activationScripts.lockRootPassword = lib.mkIf cfg.lockRoot {
      deps = ["users"];
      text = ''
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
      '';
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
