# vpush (rust/tools/vpush): push this host's builds to the fleet cache.
#
# vcache (features/nix/vcache) serves the cache host's /nix/store and signs narinfos on
# the fly, so "pushing to vcache" means getting each built closure into the cache
# host's store. Two halves:
#   - nix.settings.post-build-hook runs `vpush hook`, which appends the build's
#     $OUT_PATHS to the spool (/var/lib/vpush/spool, one file per build) and exits 0
#     whatever happens: a cache problem never fails a build.
#   - vpush.service drains the spool: per item, the closure from the local store
#     database, then `ssh <cache> nix-daemon --stdio` (the worker protocol), temp roots
#     on the cache side, QueryValidPaths to skip what it has, and AddToStoreNar for the
#     rest, references first, `jobs` at a time. Transient failures are retried on an
#     id_effect Schedule (2s, 4s, 8s, 16s); an item that still fails stays in the spool
#     and the next drain (every `interval`) tries again, so a cache that was down gets
#     its backlog once it is back. An item the cache refuses moves to spool/failed/.
#
# The cache is the first entry of common/fleet.nix's `binaryCaches` that is not this
# host, never a host name here. A host never pushes to itself: on a cache host (drakkar)
# enabling this is an evaluation error. profiles/base.nix switches it on automatically
# wherever `fleet.pushesToCache` holds: every builder-role host that is not a cache
# (huginn and muninn today; drakkar is the cache). Nothing is opt-in. Rollback, per host
# or profile, is the one option `features.nix.vpush.enable = lib.mkForce false;`.
#
# Trust: which mode the fleet uses. vpush connects as the operator (settings.username),
# with the operator's own key (~/.ssh/id_ed25519, whose public half is the host's
# `operatorKey` in common/fleet.nix and which features/fleet/operator-ssh.nix already
# authorises on every host). The operator is in the cache host's trusted-users
# (features/nixos/users, operatorTrusted defaults to true, as deploy-rs and the remote
# builder need), so the daemon reports `trusted` and vpush uploads with
# dont_check_sigs, the same trust `nix copy --no-check-sigs` from deploy-rs uses. When
# features.hardening.storeSigning is on (it is off fleet-wide today), the host's store
# signing key is handed to vpush as well: against a daemon that does NOT trust it,
# vpush signs every path with it (Nix's key format), and the cache's require-sigs
# accepts the path if its trusted-public-keys lists the key (storeSigning.publicKeys).
# A dedicated push key would need a receiving user on the cache side; the operator key
# needs nothing new, and is no more trust than deploy-rs already has.
#
# Sandbox: a static system user `vpush` (the hook, running as root under nix-daemon,
# writes the spool; the user owns it and removes items), ProtectSystem=strict with the
# store and the database read-only. The ssh key and the signing key come in as systemd
# credentials (LoadCredential), so the service never reads the operator's home. The
# cache's host key is learnt on first contact (StrictHostKeyChecking=accept-new into
# /var/lib/vpush/known_hosts): common/fleet.nix holds no host keys, and the path is the
# tailnet.
#
# Health probe (on a pushing host):
#   systemctl is-active vpush && ls /var/lib/vpush/spool   # empty once drained
#   journalctl -u vpush -o cat | grep 'uploaded'
{
  config,
  lib,
  pkgs,
  settings,
  ...
}: let
  fleet = import ../../../common/fleet.nix;
  cfg = config.features.nix.vpush;
  inherit (settings) hostname;

  vpush = pkgs.callPackage ../../../rust/tools/vpush/default.nix {};
  stateDir = "/var/lib/vpush";
  spool = "${stateDir}/spool";

  others = builtins.filter (c: c.name != hostname) fleet.binaryCaches;
  cache =
    if others == []
    then null
    else builtins.head others;
  isCache = builtins.any (c: c.name == hostname) fleet.binaryCaches;

  signing = config.features.hardening.storeSigning or {enable = false;};

  # The hook: never a non-zero exit, whatever vpush does.
  hook = pkgs.writeShellScript "vpush-post-build-hook" ''
    ${vpush}/bin/vpush hook --spool ${spool}
    exit 0
  '';

  sshOptions = [
    "-F"
    "/dev/null"
    "-i"
    "%d/ssh-key"
    "-o"
    "IdentitiesOnly=yes"
    "-o"
    "BatchMode=yes"
    "-o"
    "StrictHostKeyChecking=accept-new"
    "-o"
    "UserKnownHostsFile=${stateDir}/known_hosts"
    "-o"
    "ConnectTimeout=10"
    "-o"
    "ServerAliveInterval=15"
    "-o"
    "ServerAliveCountMax=4"
  ];

  args =
    [
      "daemon"
      "--spool"
      spool
      "--ssh"
      cfg.sshDestination
      "--ssh-program"
      "${pkgs.openssh}/bin/ssh"
      "--remote-command"
      cfg.remoteCommand
      "--jobs"
      (toString cfg.jobs)
      "--interval"
      cfg.interval
    ]
    ++ lib.concatMap (o: ["--ssh-arg" o]) sshOptions
    ++ lib.optionals (cfg.signKeyFile != null) ["--sign-key-file" "%d/sign-key"];
in {
  options.features.nix.vpush = {
    sshDestination = lib.mkOption {
      type = lib.types.str;
      default =
        if cache == null
        then ""
        else "${settings.username}@${fleet.hosts.${cache.name}.tailscaleIp}";
      defaultText = lib.literalExpression ''"<operator>@<tailscaleIp of the first other fleet.binaryCaches host>"'';
      description = "Where `ssh` reaches the cache host's nix-daemon.";
    };

    sshKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${settings.userdir}/.ssh/id_ed25519";
      defaultText = lib.literalExpression ''"''${settings.userdir}/.ssh/id_ed25519"'';
      description = "The ssh identity, handed to the service as a credential (the operator key by default; see this file's header).";
    };

    remoteCommand = lib.mkOption {
      type = lib.types.str;
      default = "/run/current-system/sw/bin/nix-daemon --stdio";
      description = "What ssh runs on the cache host: a worker-protocol session on stdio. A full path, so it does not depend on the login shell's PATH.";
    };

    signKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if signing.enable
        then signing.secretKeyFile
        else null;
      defaultText = lib.literalExpression "features.hardening.storeSigning.secretKeyFile when storeSigning is on, else null";
      description = "This host's Nix signing key, used when the cache's daemon does not trust the vpush client.";
    };

    jobs = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Uploads at once (each on its own ssh session).";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "10s";
      description = "How often the spool is drained (s, m or h suffix).";
    };
  };

  config = {
    assertions = [
      {
        assertion = !isCache;
        message = "features.nix.vpush: ${hostname} is a fleet binary cache (common/fleet.nix binaryCaches); a cache never pushes to itself. Leave vpush off here.";
      }
      {
        assertion = cfg.sshDestination != "";
        message = "features.nix.vpush: common/fleet.nix lists no binary cache other than ${hostname}, so there is nothing to push to.";
      }
    ];

    environment.systemPackages = [vpush];

    nix.settings.post-build-hook = hook;

    users.users.vpush = {
      isSystemUser = true;
      group = "vpush";
      home = stateDir;
      description = "vpush, pushes builds to the fleet cache";
    };
    users.groups.vpush = {};

    # The spool exists before the first build, whether the service has started or not.
    systemd.tmpfiles.rules = ["d ${spool} 0700 vpush vpush -"];

    systemd.services.vpush = {
      description = "vpush: drain the build spool to the fleet binary cache";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "tailscaled.service" "systemd-tmpfiles-setup.service"];
      startLimitIntervalSec = 0;

      serviceConfig = {
        Type = "simple";
        ExecStart = "${vpush}/bin/vpush ${lib.escapeShellArgs args}";
        Restart = "always";
        RestartSec = "10s";
        LoadCredential = ["ssh-key:${cfg.sshKeyFile}"] ++ lib.optional (cfg.signKeyFile != null) "sign-key:${cfg.signKeyFile}";

        User = "vpush";
        Group = "vpush";
        StateDirectory = "vpush";
        StateDirectoryMode = "0700";
        UMask = "0077";
        Nice = 10;

        ProtectSystem = "strict";
        ReadOnlyPaths = ["/nix/store" "/nix/var/nix/db"];
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectProc = "invisible";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = [""];
        AmbientCapabilities = [""];
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service" "~@privileged"];
        SystemCallErrorNumber = "EPERM";
      };
    };
  };
}
