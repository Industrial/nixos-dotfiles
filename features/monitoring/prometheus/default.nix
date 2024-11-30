{...}: {
  services = {
    prometheus = {
      enable = true;
      listenAddress = "0.0.0.0";
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
                "0.0.0.0:9002"
              ];
            }
          ];
        }
      ];
    };
  };
}
