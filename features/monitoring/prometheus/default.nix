{...}: {
  services = {
    prometheus = {
      enable = true;
      listenAddress = "localhost";
      port = 9001;
      exporters = {
        node = {
          enable = true;
          port = 9002;
          enabledCollectors = ["systemd"];
        };
      };
      scrapeConfigs = [
        {
          job_name = "nodes";
          scrape_interval = "1s";
          static_configs = [
            {
              targets = [
                "localhost:9002"
              ];
            }
          ];
        }
      ];
    };
  };
}
