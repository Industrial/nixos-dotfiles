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

      # NOTE: deliberately NO uid pin on the datasource. This Grafana
      # version's provisioner aborts startup ("data source not found")
      # if provisioning tries to change the uid of an existing datasource.
      # Dashboards reference the DB-assigned uid of the first datasource:
      # PBFA97CFB590B2093 (stable since db creation).
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