{settings, ...}: {
  # Comprehensive Prometheus monitoring stack
  services = {
    prometheus = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = 9001;

      # Scrape configurations
      scrapeConfigs = [
        {
          job_name = "nodes";
          scrape_interval = "1s";
          # Explicit host labels so dashboards legend by fleet hostname
          # instead of raw instance addresses. Local host uses 0.0.0.0,
          # remote hosts use their hostnames.
          static_configs = [
            {
              targets = ["0.0.0.0:9002"];
              labels = {host = settings.hostname;};
            }
            {
              targets = ["mimir:9002"];
              labels = {host = "mimir";};
            }
            {
              targets = ["drakkar:9002"];
              labels = {host = "drakkar";};
            }
            {
              targets = ["huginn:9002"];
              labels = {host = "huginn";};
            }
            {
              targets = ["muninn:9002"];
              labels = {host = "muninn";};
            }
          ];
        }
      ];
    };
  };
}
