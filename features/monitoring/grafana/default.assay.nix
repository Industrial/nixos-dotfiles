# Assay: Grafana service and its provisioning.
#
# Service claims read the evaluated NixOS config (services.grafana.*), so a value moved through
# mkMerge or an import still counts. The dashboard is JSON, i.e. the artifact itself, and is
# read and parsed as such.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {
    modules = [./default.nix];
    settings.hostname = "mimir";
  };
  inherit (cfg.services) grafana;
  inherit (grafana.provision.datasources.settings) datasources;
  ds = builtins.head datasources;
  provider = builtins.head grafana.provision.dashboards.settings.providers;
  fleet = builtins.fromJSON (builtins.readFile ./dashboards/fleet.json);
  panelTitles = map (p: p.title) fleet.panels;
  fleetTargets =
    builtins.concatMap (p: p.targets or [])
    (builtins.filter (p: p.type != "row") fleet.panels);
  # uid of the DB-assigned Prometheus datasource on mimir; provisioning
  # must NOT set a uid (Grafana aborts when rewriting an existing one).
  liveDsUid = "PBFA97CFB590B2093";

  # GH-248: the "Nix and fleet" dashboard, and the metrics its panels name.
  nixDash = builtins.fromJSON (builtins.readFile ./dashboards/nix.json);
  nixTargets = builtins.concatMap (p: p.targets or []) (builtins.filter (p: p.type != "row") nixDash.panels);
  inherit (nixos) lib;
  # Every metric name a panel uses: identifiers with an exporter's prefix.
  prefixes = ["vexporter_" "vci_" "vdeploy_" "vhealth_" "vverify_" "vcache_" "node_"];
  metricsIn = expr:
    builtins.filter (t: builtins.any (p: lib.hasPrefix p t) prefixes)
    (map builtins.head (builtins.filter builtins.isList (builtins.split "([a-z][a-z0-9_]*)" expr)));
  panelMetrics = lib.unique (builtins.concatMap (t: metricsIn t.expr) nixTargets);
  # What the exporters write: their sources (node_exporter's own names are its).
  tools = ["vexporter" "vci" "vdeploy" "vhealth" "vverify" "vcache"];
  sources = builtins.concatMap (tool: let
    dir = ../../../rust/tools + "/${tool}/src";
  in
    map (f: builtins.readFile (dir + "/${f}")) (builtins.filter (lib.hasSuffix ".vlt") (builtins.attrNames (builtins.readDir dir))))
  tools;
  written = m: lib.hasPrefix "node_" m || builtins.any (s: lib.hasInfix "\"${m}" s || lib.hasInfix "${m} " s || lib.hasInfix "${m}{" s) sources;
in
  assay.suite "grafana" {
    enablesGrafana = assay.eq grafana.enable true;
    # 9000 is taken on mimir by the rootless container stack (yb-tserver UI).
    listensOn3000 = assay.eq grafana.settings.server.http_port 3000;
    listensOnAllAddresses = assay.eq grafana.settings.server.http_addr "0.0.0.0";
    domainIsHostname = assay.eq grafana.settings.server.domain "mimir";
    # Reachability is the tailnet's job: the feature opens no firewall ports itself.
    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);

    analyticsReportingOff = assay.eq grafana.settings.analytics.reporting_enabled false;
    feedbackLinksOff = assay.eq grafana.settings.analytics.feedback_links_enabled false;
    gravatarOff = assay.eq grafana.settings.security.disable_gravatar true;

    # Exactly one datasource: the local Prometheus (features/monitoring/prometheus, port 9001).
    singlePrometheusDatasource = assay.eq (map (d: d.type) datasources) ["prometheus"];
    datasourcePointsAtPrometheusPort = assay.eq ds.url "http://0.0.0.0:9001";
    datasourceIsDefault = assay.eq ds.isDefault true;
    datasourceUidNotPinned = assay.eq (ds.uid or null) null;

    # A provider path must be a DIRECTORY; a single-file path never provisioned anything.
    dashboardProviderReadsDirectory = assay.eq provider.options.path ./dashboards;
    dashboardProviderIsFileType = assay.eq provider.options.type "file";

    fleetDashboardValidJson = assay.eq fleet.title "Fleet Overview";
    fleetDashboardHasFixedUid = assay.eq fleet.uid "fleet-overview";
    fleetDashboardRefreshes = assay.eq fleet.refresh "10s";
    fleetQueriesUseLiveDatasourceUid =
      assay.eq (builtins.all (t: t.datasource.uid == liveDsUid) fleetTargets) true;
    fleetCoversEssentials =
      assay.eq
      (builtins.all
        (t: builtins.elem t panelTitles)
        ["Hosts up" "Load average (1m)" "Memory used" "CPU busy" "Root filesystem used" "Network in" "Network out"])
      true;
    legendsByHostLabel =
      assay.eq
      (builtins.all (t: t.legendFormat == "{{host}}" || t.legendFormat == "{{host}} {{device}}") fleetTargets)
      true;

    # GH-248: the "Nix and fleet" dashboard is provisioned from the same directory, has
    # panels, uses the live datasource, and names only metrics some exporter writes, so a typo
    # cannot ship as an empty panel.
    nixDashboardProvisioned = assay.eq [(builtins.pathExists (provider.options.path + "/nix.json")) nixDash.uid] [true "nix-and-fleet"];
    nixDashboardHasPanels = assay.eq ((builtins.length nixTargets) >= 15) true;
    nixDashboardUsesTheLiveDatasource = assay.eq (lib.unique (map (t: t.datasource.uid) nixTargets)) [liveDsUid];
    nixDashboardMetricsExist = assay.eq (builtins.filter (m: !(written m)) panelMetrics) [];
    nixDashboardNamesVexporter = assay.eq (builtins.elem "vexporter_deploy_lag_seconds" panelMetrics) true;
    nixDashboardNamesVcache = assay.eq (builtins.all (m: builtins.elem m panelMetrics) ["vcache_narinfo_requests_total" "vcache_nar_bytes_served_total"]) true;
    # The check bites: a name no exporter writes is caught.
    aTypoIsCaught = assay.eq [(written "vexporter_deploy_lag_secnds") (written "vci_build_seconds")] [false true];
  }
