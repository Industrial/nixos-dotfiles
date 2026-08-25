{settings, ...}: {
  services = {
    homepage-dashboard = {
      enable = true;

      # 8080 is qbittorrent-nox's WebUI; homepage moves to 8083.
      listenPort = 8083;

      # Homepage v1 validates the request Host header against
      # HOMEPAGE_ALLOWED_HOSTS; the module default only allows localhost:8082,
      # so any request addressed to the host itself failed host validation.
      allowedHosts = "${settings.hostname}:8083,localhost:8083,127.0.0.1:8083";

      # https://gethomepage.dev/latest/configs/settings/
      settings = {
        title = "Dashboard";
        theme = "dark";
        color = "slate";
      };

      # https://gethomepage.dev/latest/configs/bookmarks/
      bookmarks = [
        {
          Developer = [
            {
              Github = [
                {
                  abbr = "GH";
                  href = "https://github.com/Industrial";
                }
              ];
            }
          ];
        }
        {
          Entertainment = [
            {
              YouTube = [
                {
                  abbr = "YT";
                  href = "https://youtube.com/";
                }
              ];
            }
          ];
        }
      ];

      # https://gethomepage.dev/latest/configs/services/
      services = [
        {
          Monitoring = [
            {
              Grafana = {
                icon = "https://grafana.com/img/fav32.png";
                # Grafana listens on 3000; mimir's rootless container stack
                # (monorepo compose, yb-tserver UI) owns 9000.
                href = "http://${settings.hostname}:3000";
                description = "Grafana dashboard for monitoring";
              };
            }
            {
              Prometheus = {
                icon = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/prometheus.svg";
                href = "http://${settings.hostname}:9001";
                description = "Prometheus monitoring system and time series database";
              };
            }
            {
              Syncthing = {
                icon = "https://raw.githubusercontent.com/syncthing/syncthing/main/assets/logo.ico";
                href = "http://${settings.hostname}:8384";
                description = "Syncthing is a continuous file synchronization program";
              };
            }
          ];
        }
        {
          Search = [
            {
              SearXNG = {
                icon = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/searxng.svg";
                href = "http://${settings.hostname}:4001";
                description = "SearXNG is a free anonymous google";
              };
            }
            {
              Invidious = {
                icon = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/invidious.svg";
                href = "http://${settings.hostname}:4000";
                description = "Invidious is an alternative front-end to YouTube";
              };
            }
          ];
        }
        {
          Media = [
            {
              Jackett = {
                icon = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/jackett.svg";
                href = "http://${settings.hostname}:9117";
                description = "Indexer Proxy";
              };
            }
            {
              FlexGet = {
                icon = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/flexget.svg";
                href = "http://${settings.hostname}:5050";
                description = "Download Automation";
              };
            }
            {
              Transmission = {
                icon = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/transmission.svg";
                href = "http://${settings.hostname}:9091";
                description = "Torrent Client";
              };
            }
            {
              qBittorrent = {
                icon = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/qbittorrent.svg";
                href = "http://${settings.hostname}:8080";
                description = "Torrent Client";
              };
            }
            {
              Jellyfin = {
                icon = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/jellyfin.svg";
                href = "http://${settings.hostname}:8096";
                description = "Media Player";
              };
            }
          ];
        }
      ];

      # https://gethomepage.dev/latest/configs/widgets/
      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
        {
          search = {
            provider = "duckduckgo";
            target = "_blank";
          };
        }
      ];
    };
  };
}
