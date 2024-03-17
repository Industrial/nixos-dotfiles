let
  pkgs = import <nixpkgs> {};
  config = {
    services = {
      prometheus = {
        listenAddress = "testaddress";
        port = 9090;
      };
    };
  };
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings config;};
in [
  {
    name = "grafana_test";
    actual = feature.services.grafana.enable;
    expected = true;
  }
  {
    name = "grafana_test";
    actual = feature.services.grafana.settings.analytics;
    expected = {
      feedback_links_enabled = false;
      reporting_enabled = false;
    };
  }
  {
    name = "grafana_test";
    actual = feature.services.grafana.settings.security.disable_gravatar;
    expected = true;
  }
  {
    name = "grafana_test";
    actual = feature.services.grafana.settings.server;
    expected = {
      domain = "localhost";
      enforce_domain = false;
      http_addr = "127.0.0.1";
      http_port = 9000;
    };
  }
  {
    name = "grafana_test";
    actual = feature.services.grafana.provision.datasources.settings.datasources;
    expected = [
      {
        name = "Prometheus";
        type = "prometheus";
        access = "proxy";
        url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
        isDefault = true;
      }
    ];
  }
  {
    name = "grafana_test";
    actual = feature.services.grafana.provision.dashboards.settings.providers;
    expected = [
      {
        options.name = "default";
        options.type = "file";
        options.path = ./dashboards/host.json;
      }
    ];
  }
]
