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
          Media = [
            {
              Transmission = {
                icon = "https://transmissionbt.com/assets/images/Transmission_icon.png";
                href = "http://${settings.hostname}:9091";
                description = "A Fast, Easy and Free Bittorrent Client For macOS, Windows and Linux";
              };
            }
            {
              Lidarr = {
                icon = "http://${settings.hostname}:8686/Content/Images/logo.svg";
                href = "http://${settings.hostname}:8686";
                description = "Lidarr is a music collection manager for Usenet and BitTorrent users";
              };
            }
            {
              Radarr = {
                icon = "http://${settings.hostname}:7878/Content/Images/logo.svg";
                href = "http://${settings.hostname}:7878";
                description = "Radarr is a movie collection manager for Usenet and BitTorrent users";
              };
            }
            {
              Readarr = {
                icon = "http://${settings.hostname}:8787/Content/Images/logo.svg";
                href = "http://${settings.hostname}:8787";
                description = "Readarr is a book collection manager for Usenet and BitTorrent users";
              };
            }
            {
              Prowlarr = {
                icon = "http://${settings.hostname}:9696/Content/Images/logo.svg";
                href = "http://${settings.hostname}:9696";
                description = "Prowlarr is a software that allows you to manage multiple indexers for your torrent client";
              };
            }
            {
              Sonarr = {
                icon = "http://${settings.hostname}:8989/Content/Images/logo.svg";
                href = "http://${settings.hostname}:8989";
                description = "Sonarr is a software that helps you find, download and organize your TV shows";
              };
            }
            {
              Whisparr = {
                icon = "http://${settings.hostname}:6969/Content/Images/logo.svg";
                href = "http://${settings.hostname}:6969";
                description = "Whisparr is a software that helps you find, download and organize your PORN ITS PORN";
              };
            }
            {
              Jellyfin = {
                icon = "http://${settings.hostname}:8096/web/assets/img/banner-light.png";
                href = "http://${settings.hostname}:8096";
                description = "Jellyfin is a Free Software Media System that puts you in control of managing and streaming your media.";
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
