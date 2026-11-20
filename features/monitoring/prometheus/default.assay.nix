# Assay: Prometheus and its fleet scrape config.
#
# Claims read the evaluated services.prometheus.scrapeConfigs, not the module text, so they
# hold however the host list is produced (inline, or from common/fleet.nix) and fail only if
# the scrape config the server actually gets changes.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {
    modules = [./default.nix];
    settings.hostname = "test-host";
  };
  prom = cfg.services.prometheus;
  jobs = prom.scrapeConfigs;
  nodes = builtins.head jobs;
in
  assay.suite "prometheus" {
    enablesPrometheus = assay.eq prom.enable true;
    # Grafana's datasource (features/monitoring/grafana) points at this port.
    listensOn9001 = assay.eq prom.port 9001;
    listensOnAllAddresses = assay.eq prom.listenAddress "0.0.0.0";
    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);

    onlyTheNodesJob = assay.eq (map (j: j.job_name) jobs) ["nodes"];
    oneSecondScrape = assay.eq nodes.scrape_interval "1s";

    # Local node_exporter by address, then every fleet host by name, all on node_exporter's 9002.
    scrapesEveryFleetHost =
      assay.eq
      (map (c: c.targets) nodes.static_configs)
      [["0.0.0.0:9002"] ["mimir:9002"] ["drakkar:9002"] ["huginn:9002"] ["muninn:9002"]];
    # Explicit host labels so dashboards legend by fleet hostname instead of raw addresses;
    # the local entry carries this host's own name.
    allHostsLabeled =
      assay.eq
      (map (c: c.labels.host) nodes.static_configs)
      ["test-host" "mimir" "drakkar" "huginn" "muninn"];
  }
