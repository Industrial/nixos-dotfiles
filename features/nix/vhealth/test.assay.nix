# Colocated suite for features/nix/vhealth/test.nix — the VM test whose service is active
# per systemd with its port closed, and which vhealth must report down.
#
# Evaluates the test's node (no VM is booted here; `nix build .#checks.x86_64-linux.vhealth-vm`
# runs it), so these claims are about what the machine under test is.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {inherit pkgs;};
  inherit (test.nodes) machine;
  inherit ((builtins.fromJSON (builtins.unsafeDiscardStringContext machine.features.nix.vhealth.probesJson))) probes;
  byName = builtins.listToAttrs (map (p: {
      inherit (p) name;
      value = p;
    })
    probes);
in
  assay.suite "vhealth-vm-test" {
    named = assay.eq test.name "vm-test-run-vhealth-vm";
    runsTheDaemon = assay.eq (machine.systemd.services ? vhealth) true;

    # The liar is a plain long-running unit (systemd will call it active) and its probe
    # points at a port nothing in the machine listens on.
    liarIsActiveButServesNothing =
      assay.eq [(machine.systemd.services.liar.serviceConfig.Type or "simple") (builtins.match ".*/bin/sleep infinity" machine.systemd.services.liar.serviceConfig.ExecStart != null)] ["simple" true];
    liarProbe = assay.eq [byName.liar.type byName.liar.host byName.liar.port byName.liar.critical] ["tcp" "127.0.0.1" 8081 true];

    # Every probe type is exercised.
    everyType = assay.eq (builtins.sort builtins.lessThan (map (p: p.type) probes)) ["command" "command" "file" "http" "tcp" "unix"];
    slowIsNotCritical = assay.eq [byName.slow.critical byName.slow.timeoutMs] [false 500];

    exporterReadsTheTextfileDir =
      assay.eq machine.services.prometheus.exporters.node.extraFlags ["--collector.textfile.directory=/var/lib/prometheus-node-exporter-text"];
  }
