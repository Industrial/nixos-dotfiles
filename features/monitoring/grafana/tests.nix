args @ {...}: let
  feature = import ./default.nix args;
in {
  test_services_grafana_enable = {
    expr = feature.services.grafana.enable;
    expected = true;
  };
  test_services_grafana_settings_analytics = {
    expr = feature.services.grafana.settings.analytics;
    expected = {
      feedback_links_enabled = false;
      reporting_enabled = false;
    };
  };
  test_services_grafana_settings_security_disable_gravatar = {
    expr = feature.services.grafana.settings.security.disable_gravatar;
    expected = true;
  };
  test_services_grafana_settings_server = {
    expr = feature.services.grafana.settings.server;
    expected = {
      domain = "localhost";
      enforce_domain = false;
      http_addr = "127.0.0.1";
      http_port = 9000;
    };
  };
  test_services_grafana_provision_datasources_settings_datasources = {
    expr = feature.services.grafana.provision.datasources.settings.datasources;
    expected = [
      {
        name = "Prometheus";
        type = "prometheus";
        access = "proxy";
        url = "http://localhost:9001";
        isDefault = true;
      }
    ];
  };
  test_services_grafana_provision_dashboards_settings_providers = {
    expr = feature.services.grafana.provision.dashboards.settings.providers;
    expected = [
      {
        options.name = "default";
        options.type = "file";
        options.path = ./dashboards/host.json;
      }
    ];
  };
}
