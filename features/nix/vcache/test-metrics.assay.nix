# Colocated suite for features/nix/vcache/test-metrics.nix (GH-248). Evaluates the node; no
# VM is booted here (`nix build .#checks.x86_64-linux.vcache-metrics-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test-metrics.nix {inherit pkgs;};
  c = test.nodes.cache;
in
  assay.suite "vcache-metrics-vm-test" {
    named = assay.eq test.name "vm-test-run-vcache-metrics-vm";
    nodeExporterOn = assay.eq c.services.prometheus.exporters.node.enable true;
    countersOn = assay.eq c.systemd.services.vcache.environment.VCACHE_TEXTFILE_DIR "/var/lib/prometheus-node-exporter-text";
  }
