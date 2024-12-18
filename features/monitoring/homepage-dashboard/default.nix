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
          ];
        }
        {
          Documents = [
            {
              CryptDrive = {
                icon = "https://sandbox.cryptpad.info/api/logo?ver=2024.3.0-13#%7B%22cfg%22%3A%7B%22baseUrl%22%3A%22%2Fdrive%2F%22%2C%22paths%22%3A%7B%22text%22%3A%22%2Fcomponents%2Frequirejs-plugins%2Flib%2Ftext%22%2C%22json%22%3A%22%2Fcomponents%2Frequirejs-plugins%2Fsrc%2Fjson%22%2C%22optional%22%3A%22%2Flib%2Foptional%2Foptional%22%2C%22jquery%22%3A%22%2Fcomponents%2Fjquery%2Fdist%2Fjquery.min%22%2C%22mermaid%22%3A%22%2Flib%2Fmermaid%2Fmermaid.min%22%2C%22json.sortify%22%3A%22%2Fcomponents%2Fjson.sortify%2Fdist%2FJSON.sortify%22%2C%22cm%22%3A%22%2Fcomponents%2Fcodemirror%22%2C%22tui-code-snippet%22%3A%22%2Flib%2Fcalendar%2Ftui-code-snippet.min%22%2C%22tui-date-picker%22%3A%22%2Flib%2Fcalendar%2Fdate-picker%22%2C%22netflux-client%22%3A%22%2Fcomponents%2Fnetflux-websocket%2Fnetflux-client%22%2C%22chainpad-netflux%22%3A%22%2Fcomponents%2Fchainpad-netflux%2Fchainpad-netflux%22%2C%22chainpad-listmap%22%3A%22%2Fcomponents%2Fchainpad-listmap%2Fchainpad-listmap%22%2C%22cm-extra%22%3A%22%2Flib%2Fcodemirror-extra-modes%22%2C%22asciidoctor%22%3A%22%2Flib%2Fasciidoctor%2Fasciidoctor.min%22%7D%2C%22map%22%3A%7B%22*%22%3A%7B%22css%22%3A%22%2Fcomponents%2Frequire-css%2Fcss.js%22%2C%22less%22%3A%22%2Fcommon%2FRequireLess.js%22%2C%22%2Fbower_components%2Ftweetnacl%2Fnacl-fast.min.js%22%3A%22%2Fcomponents%2Ftweetnacl%2Fnacl-fast.min.js%22%7D%7D%2C%22waitSeconds%22%3A600%2C%22urlArgs%22%3A%22ver%3D2024.3.0-13%22%7D%2C%22req%22%3A%5B%22%2Fcommon%2Floading.js%22%5D%2C%22pfx%22%3A%22https%3A%2F%2Fcryptpad.fr%22%2C%22themeOS%22%3A%22light%22%2C%22lang%22%3A%22en%22%2C%22time%22%3A1712591463519%7D";
                href = "http://127.0.0.1:4020/drive";
                description = "CryptDrive is a self-hosted, end-to-end encrypted file storage service";
              };
            }
          ];
        }
        {
          LLM = [
            {
              Ollama = {
                icon = "https://sandbox.cryptpad.info/api/logo?ver=2024.3.0-13#%7B%22cfg%22%3A%7B%22baseUrl%22%3A%22%2Fdrive%2F%22%2C%22paths%22%3A%7B%22text%22%3A%22%2Fcomponents%2Frequirejs-plugins%2Flib%2Ftext%22%2C%22json%22%3A%22%2Fcomponents%2Frequirejs-plugins%2Fsrc%2Fjson%22%2C%22optional%22%3A%22%2Flib%2Foptional%2Foptional%22%2C%22jquery%22%3A%22%2Fcomponents%2Fjquery%2Fdist%2Fjquery.min%22%2C%22mermaid%22%3A%22%2Flib%2Fmermaid%2Fmermaid.min%22%2C%22json.sortify%22%3A%22%2Fcomponents%2Fjson.sortify%2Fdist%2FJSON.sortify%22%2C%22cm%22%3A%22%2Fcomponents%2Fcodemirror%22%2C%22tui-code-snippet%22%3A%22%2Flib%2Fcalendar%2Ftui-code-snippet.min%22%2C%22tui-date-picker%22%3A%22%2Flib%2Fcalendar%2Fdate-picker%22%2C%22netflux-client%22%3A%22%2Fcomponents%2Fnetflux-websocket%2Fnetflux-client%22%2C%22chainpad-netflux%22%3A%22%2Fcomponents%2Fchainpad-netflux%2Fchainpad-netflux%22%2C%22chainpad-listmap%22%3A%22%2Fcomponents%2Fchainpad-listmap%2Fchainpad-listmap%22%2C%22cm-extra%22%3A%22%2Flib%2Fcodemirror-extra-modes%22%2C%22asciidoctor%22%3A%22%2Flib%2Fasciidoctor%2Fasciidoctor.min%22%7D%2C%22map%22%3A%7B%22*%22%3A%7B%22css%22%3A%22%2Fcomponents%2Frequire-css%2Fcss.js%22%2C%22less%22%3A%22%2Fcommon%2FRequireLess.js%22%2C%22%2Fbower_components%2Ftweetnacl%2Fnacl-fast.min.js%22%3A%22%2Fcomponents%2Ftweetnacl%2Fnacl-fast.min.js%22%7D%7D%2C%22waitSeconds%22%3A600%2C%22urlArgs%22%3A%22ver%3D2024.3.0-13%22%7D%2C%22req%22%3A%5B%22%2Fcommon%2Floading.js%22%5D%2C%22pfx%22%3A%22https%3A%2F%2Fcryptpad.fr%22%2C%22themeOS%22%3A%22light%22%2C%22lang%22%3A%22en%22%2C%22time%22%3A1712591463519%7D";
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
