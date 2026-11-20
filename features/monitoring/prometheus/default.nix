{settings, ...}: let
  fleet = import ../../../common/fleet.nix;
in {
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
          # remote hosts use their hostnames, in common/fleet.nix order.
          static_configs =
            [
              {
                targets = ["0.0.0.0:9002"];
                labels = {host = settings.hostname;};
              }
            ]
            ++ map (name: {
              targets = ["${name}:9002"];
              labels = {host = name;};
            })
            fleet.order;
        }
      ];
    };
  };
}
