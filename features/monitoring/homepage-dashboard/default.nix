{settings, ...}: {
  services = {
    homepage-dashboard = {
      enable = true;

      listenPort = 8080;

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
                href = "http://${settings.hostname}:9000";
                description = "Grafana dashboard for monitoring";
              };
            }
            {
              Prometheus = {
                icon = "https://prometheus.io/assets/prometheus_logo_grey.svg";
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
                icon = "https://invidious.snopyta.org/favicon.ico";
                href = "http://${settings.hostname}:4001";
                description = "SearXNG is a free anonymous google";
              };
            }
            {
              Invidious = {
                icon = "https://invidious.snopyta.org/favicon.ico";
                href = "http://${settings.hostname}:4000";
                description = "Invidious is an alternative front-end to YouTube";
              };
            }
          ];
        }
        {
          News = [
            {
              TinyTinyRSS = {
                icon = "https://tt-rss.org/images/ttrss-icon.png";
                href = "http://${settings.hostname}:9312";
                description = "News";
              };
            }
          ];
        }
        {
          Media = [
            {
              Transmission = {
                icon = "https://transmissionbt.com/assets/images/Transmission_icon.png";
                href = "http://${settings.hostname}:9091";
                description = "BitTorrent";
              };
            }
            {
              Lidarr = {
                icon = "http://${settings.hostname}:8686/Content/Images/logo.svg";
                href = "http://${settings.hostname}:8686";
                description = "Music";
              };
            }
            {
              Radarr = {
                icon = "http://${settings.hostname}:7878/Content/Images/logo.svg";
                href = "http://${settings.hostname}:7878";
                description = "Movies";
              };
            }
            {
              Readarr = {
                icon = "http://${settings.hostname}:8787/Content/Images/logo.svg";
                href = "http://${settings.hostname}:8787";
                description = "Books";
              };
            }
            {
              Prowlarr = {
                icon = "http://${settings.hostname}:9696/Content/Images/logo.svg";
                href = "http://${settings.hostname}:9696";
                description = "Indexer";
              };
            }
            {
              Sonarr = {
                icon = "http://${settings.hostname}:8989/Content/Images/logo.svg";
                href = "http://${settings.hostname}:8989";
                description = "TV Shows";
              };
            }
            {
              Whisparr = {
                icon = "http://${settings.hostname}:6969/Content/Images/logo.svg";
                href = "http://${settings.hostname}:6969";
                description = "Porn";
              };
            }
            {
              Jellyfin = {
                icon = "http://${settings.hostname}:8096/web/assets/img/banner-light.png";
                href = "http://${settings.hostname}:8096";
                description = "Media Player";
              };
            }
          ];
        }
        {
          LLM = [
            {
              Ollama = {
                # icon = "";
                href = "http://0.0.0.0:5001/drive";
                description = "Fully-featured, beautiful web interface for Ollama LLMs - built with NextJS. Deploy with a single click.";
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
