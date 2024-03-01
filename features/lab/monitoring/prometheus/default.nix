{
  config,
  pkgs,
  settings,
  ...
}: {
  services.prometheus.enable = true;
  services.prometheus.listenAddress = "localhost";
  services.prometheus.port = 9001;

  services.prometheus.exporters.node.enable = true;
  services.prometheus.exporters.node.port = 9002;
  services.prometheus.exporters.node.enabledCollectors = ["systemd"];

  services.prometheus.scrapeConfigs = [
    {
      job_name = "nodes";
      scrape_interval = "1s";
      static_configs = [
        {
          targets = [
            "${config.services.prometheus.listenAddress}:${toString config.services.prometheus.exporters.node.port}"
          ];
        }
      ];
    }
  ];
}
