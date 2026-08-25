# Colocated suite: homepage-dashboard module with stubbed deps.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {settings.hostname = "mimir";};
  hp = mod.services.homepage-dashboard;
  monitoring = (builtins.head (builtins.filter (s: s ? "Monitoring") hp.services)).Monitoring;
  search = (builtins.head (builtins.filter (s: s ? "Search") hp.services)).Search;
  media = (builtins.head (builtins.filter (s: s ? "Media") hp.services)).Media;
in
  assay.suite "homepage-dashboard" {
    enabled = assay.eq hp.enable true;
    listenPort = assay.eq hp.listenPort 8083;
    allowedHostsIncludeMimir =
      assay.eq hp.allowedHosts "mimir:8083,localhost:8083,127.0.0.1:8083";
    titleSet = assay.eq (hp.settings ? "title") true;
    servicesDeclared = assay.eq ((builtins.length hp.services) > 0) true;
    widgetsDeclared = assay.eq ((builtins.length hp.widgets) > 0) true;
    # Grafana runs on 3000; 9000 belongs to mimir's rootless monorepo compose
    # stack (yb-tserver UI).
    grafanaHref = assay.eq (builtins.head monitoring).Grafana.href "http://mimir:3000";
    prometheusIcon =
      assay.eq (builtins.elemAt monitoring 1).Prometheus.icon
      "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/prometheus.svg";
    searxngIcon =
      assay.eq (builtins.head search).SearXNG.icon
      "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/searxng.svg";
    jellyfinIcon =
      assay.eq (builtins.elemAt media 4).Jellyfin.icon
      "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/jellyfin.svg";
    invidiousIcon =
      assay.eq (builtins.elemAt search 1).Invidious.icon
      "https://raw.githubusercontent.com/walkxcode/dashboard-icons/master/svg/invidious.svg";
    # arr stack replaced by Jackett/FlexGet/Transmission (2026-08).
    jackettTile = assay.eq
      (builtins.elemAt media 0).Jackett.href "http://mimir:9117";
    flexgetTile = assay.eq
      (builtins.elemAt media 1).FlexGet.href "http://mimir:5050";
    transmissionTile = assay.eq
      (builtins.elemAt media 2).Transmission.href "http://mimir:9091";
    noArrTiles =
      assay.eq
      (builtins.all
        (s:
          !(s ? "Lidarr" || s ? "Radarr" || s ? "Readarr"
            || s ? "Prowlarr" || s ? "Sonarr" || s ? "Whisparr")
        )
        hp.services)
      true;
    # TinyTinyRSS and Ollama are gone from the fleet.
    noRemovedCategories =
      assay.eq (builtins.all (s: !(s ? "News" || s ? "LLM")) hp.services) true;
  }
