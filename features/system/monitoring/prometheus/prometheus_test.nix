let
  pkgs = import <nixpkgs> {};
  config = {
    services = {
      prometheus = {
        listenAddress = "localhost";
        port = 9001;
      };
      prometheus.exporters.node = {
        enable = true;
        port = 9002;
        enabledCollectors = ["systemd"];
      };
    };
  };
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings config;};
in [
  {
    actual = feature.services.prometheus.enable;
    expected = true;
  }
  {
    actual = feature.services.prometheus.listenAddress;
    expected = "localhost";
  }
  {
    actual = feature.services.prometheus.port;
    expected = 9001;
  }
  {
    actual = feature.services.prometheus.exporters.node.enable;
    expected = true;
  }
  {
    actual = feature.services.prometheus.exporters.node.port;
    expected = 9002;
  }
  {
    actual = feature.services.prometheus.exporters.node.enabledCollectors;
    expected = ["systemd"];
  }
  {
    actual = feature.services.prometheus.scrapeConfigs;
    expected = [
      {
        job_name = "nodes";
        scrape_interval = "1s";
        static_configs = [
          {
            targets = [
              "${config.services.prometheus.listenAddress}:${toString config.services.prometheus.exporters.node.port}"
            ];
          }
        ];
      }
    ];
  }
]
