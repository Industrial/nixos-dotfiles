{
  settings ? {
    hostname = "test.local";
  },
  ...
}: let
  module = import ./default.nix {inherit settings;};
in {
  # Test that the service is enabled
  testServiceEnabled = {
    expr = module.services.grafana.enable;
    expected = true;
  };

  # Test analytics settings
  testAnalyticsSettings = {
    expr = module.services.grafana.settings.analytics;
    expected = {
      feedback_links_enabled = false;
      reporting_enabled = false;
    };
  };

  # Test security settings
  testSecuritySettings = {
    expr = module.services.grafana.settings.security;
    expected = {
      disable_gravatar = true;
    };
  };

  # Test server settings
  testServerSettings = {
    expr = module.services.grafana.settings.server;
    expected = {
      domain = settings.hostname;
      enforce_domain = false;
      http_addr = "0.0.0.0";
      http_port = 9000;
    };
  };

  # Test datasource provisioning
  testDatasourceProvisioning = {
    expr = module.services.grafana.provision.datasources.settings.datasources;
    expected = [
      {
        name = "Prometheus";
        type = "prometheus";
        access = "proxy";
        url = "http://0.0.0.0:9001";
        isDefault = true;
      }
    ];
  };

  # Test dashboard provisioning
  testDashboardProvisioning = {
    expr = module.services.grafana.provision.dashboards.settings.providers;
    expected = [
      {
        options.name = "default";
        options.type = "file";
        options.path = ./dashboards/host.json;
      }
    ];
  };
}
