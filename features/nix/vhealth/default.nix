# vhealth (rust/tools/vhealth): service health from probes, not from systemd state. A unit
# can be `active` with its port closed, unchanged units are not restarted by a switch, and
# OCI containers can report inactive while serving; a probe asks the service itself.
#
# Probes are declared by the feature that owns the service, next to the service:
#
#   features.nix.vhealth.probes.vcache = {
#     type = "http";
#     url = "http://${bindIp}:${toString port}/nix-cache-info";
#     bodyContains = "StoreDir: /nix/store";
#   };
#
# The option is common/vhealth-probes.nix (options only). This feature imports it, and
# lib/features.nix keeps a feature's imports and options whether it is enabled or not, so
# the option exists on every host and any feature can declare probes; they only run where
# `features.nix.vhealth.enable` is set. A feature that declares a probe imports the file
# too, so it still evaluates on its own (its colocated assay suite).
#
# Types: tcp (host, port), http (url, status, bodyContains), unix (path), command (argv,
# no shell, exit 0), file (path, maxAge in seconds). Each has a timeout (ms) and is
# critical unless it says otherwise; the host is healthy when no critical probe is down.
#
# Output: /etc/vhealth/probes.json (what `vhealth check` reads, and what vdeploy reads
# from a new generation's toplevel before it switches), and a daemon that checks every
# `interval` on an id_effect Schedule and writes vhealth.prom (vhealth_probe_up{probe=…},
# vhealth_healthy, …) and vhealth.json into node_exporter's textfile directory
# (features/monitoring/textfile-collector.nix).
#
# Sandbox: the static system user `vhealth`, with ProtectSystem=strict; its only writable
# path is the textfile directory, through the prometheus-textfile group. Static, not a
# DynamicUser, because vdeploy (#160) runs its post-switch `vhealth check` as the same
# identity, outside this unit. Hosts restrict who may use the Nix daemon
# (features/nixos/users: allowed-users = @wheel), so `vhealth` is added to
# nix.settings.allowed-users there (access only, never trusted-users); without it the
# nix-daemon probe is down on every such host, and vdeploy rolls every switch back.
# It needs the network (it connects to the probed services), so it is not PrivateNetwork. Command probes run inside the same
# sandbox, as that user.
#
# Health probe (run on the host):
#   vhealth check            # exit 0 when every critical probe is up
#   vhealth check --json
{
  config,
  lib,
  pkgs,
  ...
}: let
  # The vhealth account and group are Voltaic's (#457): rust/tools/nixos-users.
  voltaic = import ../../nixos/users/voltaic.nix;
  inherit (lib) mkOption types;
  cfg = config.features.nix.vhealth;
  # Whether something restricts nix.settings.allowed-users on this host: the users feature
  # (profiles/base.nix, every host) or the STIG control. Read from those switches, not from
  # the merged list, which this module adds to.
  restricted =
    lib.attrByPath ["features" "nixos" "users" "enable"] false config
    || cfg.restrictedNixUsers;
  vhealth = pkgs.callPackage ../../../rust/tools/vhealth/default.nix {};
  textfileDir = "/var/lib/prometheus-node-exporter-text";

  # The fields each type needs.
  required = {
    tcp = ["host" "port"];
    http = ["url"];
    unix = ["path"];
    command = ["argv"];
    file = ["path" "maxAge"];
  };
  missing = p: builtins.filter (f: p.${f} == null || p.${f} == []) required.${p.type};

  # The JSON document rust/tools/vhealth/src/config.vlt parses: only the fields the type
  # uses, nulls left out.
  entry = name: p: let
    fields =
      {
        tcp = {inherit (p) host port;};
        http = {inherit (p) url status bodyContains;};
        unix = {inherit (p) path;};
        command = {inherit (p) argv;};
        file = {
          inherit (p) path;
          maxAgeSeconds = p.maxAge;
        };
      }
      .${
        p.type
      };
  in
    lib.filterAttrs (_: v: v != null) ({
        inherit name;
        inherit (p) type critical;
        timeoutMs = p.timeout;
      }
      // fields);
  json = builtins.toJSON {probes = lib.mapAttrsToList entry cfg.probes;};
  probesFile = pkgs.writeText "vhealth-probes.json" json;
in {
  imports = [
    ../../../common/vhealth-probes.nix
    ../../monitoring/textfile-collector.nix
  ];

  # features.nix.vhealth.probes is common/vhealth-probes.nix's, imported above (and by
  # every feature that declares a probe).
  options.features.nix.vhealth = {
    restrictedNixUsers = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Set where nix.settings.allowed-users is restricted by something other than
        features/nixos/users (which is detected): the STIG control V-268152, a test. Then
        `vhealth` is added to the list, as it is wherever the users feature is on.
      '';
    };
    interval = mkOption {
      type = types.strMatching "[0-9]+[smhdw]?";
      default = "1m";
      description = "How often the daemon checks every probe (a number of seconds, or with s, m, h, d or w).";
    };
    probesJson = mkOption {
      type = types.str;
      readOnly = true;
      default = json;
      description = "The probes as the JSON vhealth reads (/etc/vhealth/probes.json).";
    };
  };

  config = {
    assertions =
      lib.mapAttrsToList (name: p: {
        assertion = missing p == [];
        message = "features.nix.vhealth.probes.${name}: a ${p.type} probe needs ${lib.concatStringsSep ", " (missing p)}.";
      })
      cfg.probes;

    # The Nix daemon, on every vhealth host: a real query through the daemon socket, as a
    # non-root user (the `vhealth` user). A socket unit can be active, and a connect
    # can succeed, while nothing behind it answers: on 2026-11-21 a proxy held the socket
    # after a live switch and the daemon never re-bound, so every non-root `nix` call got
    # "Connection reset by peer" while systemd reported nothing wrong.
    features.nix.vhealth.probes.nix-daemon = {
      type = "command";
      argv = ["${config.nix.package}/bin/nix-store" "--store" "daemon" "--query" "--hash" "/run/current-system"];
      timeout = 5000;
      description = "the Nix daemon answers a non-root store query";
    };

    environment.systemPackages = [vhealth];
    environment.etc."vhealth/probes.json".source = probesFile;

    # The identity the probes run as: this daemon, and vdeploy's post-switch check.
    users = voltaic.fragments.vhealth;
    # It may use the Nix daemon, merged into whatever the host allows (features/nixos/users
    # sets ["@wheel"], STIG V-268152 ["root" "@wheel"]); never trusted-users. Only where
    # the list is restricted: a definition here alone would replace nixpkgs' ["*"] with
    # ["vhealth"] and lock everyone else out.
    nix.settings.allowed-users = lib.mkIf restricted ["vhealth"];

    systemd.services.vhealth = {
      description = "vhealth: the host's services probed, into node_exporter";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "systemd-tmpfiles-setup.service"];
      # Command probes (nix-store) may want a cache directory; the sandbox's own /tmp.
      environment.XDG_CACHE_HOME = "/tmp/cache";
      # A new probe set is a new ExecStart, so a switch restarts the daemon.
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs [
          "${vhealth}/bin/vhealth"
          "daemon"
          "--config"
          "${probesFile}"
          "--interval"
          cfg.interval
          "--textfile-dir"
          textfileDir
        ];
        Restart = "always";
        RestartSec = "10s";

        User = "vhealth";
        Group = "vhealth";
        SupplementaryGroups = ["prometheus-textfile"];
        # node_exporter (its own user) reads what is written: 0644 files.
        UMask = "0022";

        ProtectSystem = "strict";
        ReadWritePaths = [textfileDir];
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        # Not PrivateUsers: in its user namespace the prometheus-textfile group would be
        # unmapped, and that group is the one write the unit has. Not PrivateNetwork: it
        # connects to the services it probes.
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
