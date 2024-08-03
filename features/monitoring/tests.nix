args @ {...}: {
  grafana = import ./grafana/tests.nix args;
  homepage-dashboard = import ./homepage-dashboard/tests.nix args;
  prometheus = import ./prometheus/tests.nix args;
}
