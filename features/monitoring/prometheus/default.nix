{
  config,
  lib,
  pkgs,
  ...
}: {
  # Comprehensive Prometheus monitoring stack
  services = {
    prometheus = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = 9001;

      # Alertmanager configuration
      alertmanager = {
        enable = true;
        configuration = {
          global = {
            smtp_smarthost = "localhost:587";
            smtp_from = "alertmanager@example.com";
          };
          route = {
            group_by = ["alertname"];
            group_wait = "10s";
            group_interval = "10s";
            repeat_interval = "1h";
            receiver = "web.hook";
          };
          receivers = [
            {
              name = "web.hook";
              webhook_configs = [
                {
                  url = "http://127.0.0.1:5001/";
                }
              ];
            }
          ];
          inhibit_rules = [
            {
              source_match = {
                severity = "critical";
              };
              target_match = {
                severity = "warning";
              };
              equal = ["alertname" "dev" "instance"];
            }
          ];
        };
      };

      # Scrape configurations
      scrapeConfigs = [
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
  };

  # Create users for monitoring services
  users = {
    users = {
      alertmanager = {
        isSystemUser = true;
        group = "alertmanager";
        home = "/var/lib/alertmanager";
        createHome = true;
      };
    };
    groups = {
      alertmanager = {};
    };
  };
}
