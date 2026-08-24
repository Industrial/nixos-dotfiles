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
          secret_key = "SW2YcwTIb9zpOOhoPsMm";
        };
        server = {
          domain = settings.hostname;
          enforce_domain = false;
          http_addr = "0.0.0.0";
          # 9000 is taken on mimir by the rootless container stack (yb-tserver UI).
          http_port = 3000;
        };
      };

      # Stable datasource UID: provisioned dashboards reference it directly
      # (${DS_PROMETHEUS}/000000001 placeholders in host.json never resolved,
      # so that dashboard's panels had no working datasource).
      provision = {
        datasources = {
          settings = {
            datasources = [
              {
                name = "Prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://0.0.0.0:9001";
                uid = "prometheus";
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
                # A provider path must be a DIRECTORY; the previous
                # single-file path never provisioned anything.
                options.path = ./dashboards;
              }
            ];
          };
        };
      };
    };
  };
}