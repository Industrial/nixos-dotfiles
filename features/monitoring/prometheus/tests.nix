args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_services_prometheus_enable = {
    expr = feature.services.prometheus.enable;
    expected = true;
  };
  test_services_prometheus_listenAddress = {
    expr = feature.services.prometheus.listenAddress;
    expected = "localhost";
  };
  test_services_prometheus_port = {
    expr = feature.services.prometheus.port;
    expected = 9001;
  };
  test_services_prometheus_exporters_node_enable = {
    expr = feature.services.prometheus.exporters.node.enable;
    expected = true;
  };
  test_services_prometheus_exporters_node_port = {
    expr = feature.services.prometheus.exporters.node.port;
    expected = 9002;
  };
  test_services_prometheus_exporters_node_enabledCollectors = {
    expr = feature.services.prometheus.exporters.node.enabledCollectors;
    expected = ["systemd"];
  };
  test_services_prometheus_scrapeConfigs = {
    expr = feature.services.prometheus.scrapeConfigs;
    expected = [
      {
        job_name = "nodes";
        scrape_interval = "1s";
        static_configs = [
          {
            targets = [
              "localhost:9002"
            ];
          }
        ];
      }
    ];
  };
}
