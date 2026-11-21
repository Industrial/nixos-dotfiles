# Colocated suite for features/nix/vverify/test.nix — the VM test that corrupts a store
# path and expects vverify to report it.
#
# Evaluates the test's node (no VM is booted here; `nix build .#checks.x86_64-linux.vverify-vm`
# runs it), so these claims are about what the machine under test is: the feature, the
# planted paths, and an exporter that reads the textfile directory.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {inherit pkgs;};
  machine = test.nodes.machine;
in
  assay.suite "vverify-vm-test" {
    named = assay.eq test.name "vm-test-run-vverify-vm";
    runsTheFeature = assay.eq (machine.systemd.services ? vverify) true;
    plantsTheVictims = assay.eq (map (d: d.name) machine.system.extraDependencies) ["vverify-victim" "vverify-gone"];
    corruptsAnOverlayNotTheHostStore = assay.eq machine.virtualisation.writableStore true;
    exporterReadsTheTextfileDir =
      assay.eq machine.services.prometheus.exporters.node.extraFlags ["--collector.textfile.directory=/var/lib/prometheus-node-exporter-text"];
  }
