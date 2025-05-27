{pkgs, ...}: let
  module = import ./default.nix {inherit pkgs;};
in {
  # Test that the service is enabled
  testServiceEnabled = {
    expr = module.services.prometheus.enable;
    expected = true;
  };

  # Test basic configuration
  testBasicConfig = {
    expr = {
      listenAddress = module.services.prometheus.listenAddress;
      port = module.services.prometheus.port;
    };
    expected = {
      listenAddress = "0.0.0.0";
      port = 9001;
    };
  };

  # Test node exporter configuration
  testNodeExporter = {
    expr = {
      enable = module.services.prometheus.exporters.node.enable;
      port = module.services.prometheus.exporters.node.port;
      enabledCollectors = module.services.prometheus.exporters.node.enabledCollectors;
    };
    expected = {
      enable = true;
      port = 9002;
      enabledCollectors = ["systemd"];
    };
  };

  # Test scrape configuration
  testScrapeConfig = {
    expr = module.services.prometheus.scrapeConfigs;
    expected = [
      {
        job_name = "nodes";
        scrape_interval = "1s";
        static_configs = [
          {
            targets = [
              "0.0.0.0:9002"
            ];
          }
        ];
      }
    ];
  };
}
