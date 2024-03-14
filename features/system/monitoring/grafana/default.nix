{
  settings,
  pkgs,
  config,
  ...
}: {
  # services.grafana.settings.data_source_proxy_whitelist = ["${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}"];
  services.grafana.enable = true;
  services.grafana.settings.analytics.feedback_links_enabled = false;
  services.grafana.settings.analytics.reporting_enabled = false;
  services.grafana.settings.security.disable_gravatar = true;
  services.grafana.settings.server.domain = "localhost";
  services.grafana.settings.server.enforce_domain = false;
  services.grafana.settings.server.http_addr = "127.0.0.1";
  services.grafana.settings.server.http_port = 9000;

  services.grafana.provision.datasources.settings.datasources = [
    {
      name = "Prometheus";
      type = "prometheus";
      access = "proxy";
      url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
      isDefault = true;
    }
  ];

  services.grafana.provision.dashboards.settings.providers = [
    {
      options.name = "default";
      options.type = "file";
      options.path = ./dashboards/host.json;
    }
  ];

  # services.nginx.virtualHosts.${config.services.grafana.settings.server.domain} = {
  #   locations."/" = {
  #     proxyPass = "http://${config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
  #     proxyWebsockets = true;
  #   };
  # };
}
