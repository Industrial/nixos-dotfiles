{settings, ...}: {
  services = {
    grafana = {
      enable = true;
      settings = {
        analytics = {
          feedback_links_enabled = false;
          reporting_enabled = false;
        };
        security = {
          disable_gravatar = true;
        };
        server = {
          domain = settings.hostname;
          enforce_domain = false;
          http_addr = "0.0.0.0";
          http_port = 9000;
        };
      };
      provision = {
        datasources = {
          settings = {
            datasources = [
              {
                name = "Prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://0.0.0.0:9001";
                isDefault = true;
              }
            ];
          };
        };
        dashboards = {
          settings = {
            providers = [
              {
                options.name = "default";
                options.type = "file";
                options.path = ./dashboards/host.json;
              }
            ];
          };
        };
      };
    };
  };

  # services.nginx.virtualHosts.${config.services.grafana.settings.server.domain} = {
  #   locations."/" = {
  #     proxyPass = "http://${config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
  #     proxyWebsockets = true;
  #   };
  # };
}
