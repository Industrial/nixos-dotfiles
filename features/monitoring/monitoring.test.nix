{pkgs, ...}: {
  grafana = import ./grafana/grafana.test.nix {inherit pkgs;};
  homepage-dashboard = import ./homepage-dashboard/homepage-dashboard.test.nix {inherit pkgs;};
  prometheus = import ./prometheus/prometheus.test.nix {inherit pkgs;};
}
