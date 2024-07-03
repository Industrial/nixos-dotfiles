args @ {...}: {
  grafana = import ./grafana/tests.nix args;
  homepage-dashboard = import ./homepage-dashboard/tests.nix args;
  lxqt-qps = import ./lxqt-qps/tests.nix args;
  prometheus = import ./prometheus/tests.nix args;
}
