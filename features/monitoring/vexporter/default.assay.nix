# Colocated suite for features/monitoring/vexporter: the service that writes vexporter.prom,
# as whom, how sandboxed, into which directory.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {modules = [./default.nix];};
  svc = cfg.systemd.services.vexporter;
  sc = svc.serviceConfig;
  has = s: lib.hasInfix s sc.ExecStart;
in
  assay.suite "monitoring-vexporter" {
    startsAtBoot = assay.eq svc.wantedBy ["multi-user.target"];
    everyMinute = assay.eq [(has "--interval 1m") (has "--textfile-dir /var/lib/prometheus-node-exporter-text")] [true true];
    # Its own unprivileged user, writing only the textfile directory through its group.
    ownUser = assay.eq [sc.User cfg.users.users.vexporter.isSystemUser sc.SupplementaryGroups] ["vexporter" true ["prometheus-textfile"]];
    writesOnlyTheTextfileDir = assay.eq sc.ReadWritePaths ["/var/lib/prometheus-node-exporter-text"];
    # Read-only everywhere else, no network, no capabilities: it reads files and the DB.
    sandboxed = assay.eq [sc.ProtectSystem sc.ProtectHome sc.PrivateNetwork sc.NoNewPrivileges sc.CapabilityBoundingSet] ["strict" true true true ""];
    # Never trusted, and not even a Nix daemon user: it opens the database file read-only.
    notADaemonUser = assay.eq (builtins.elem "vexporter" (cfg.nix.settings.allowed-users or [])) false;
    # node_exporter reads 0644 files.
    readableOutput = assay.eq sc.UMask "0022";
    restartsOnFailure = assay.eq sc.Restart "always";
  }
