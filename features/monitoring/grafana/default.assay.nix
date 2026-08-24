# Colocated suite: module top-level shape with stubbed args.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "testhost";
      username = "alice";
      useremail = "a@b.c";
    };
    pkgs = {
      callPackage = path: args: "pkg";
      stdenv = {
        mkDerivation = args: args.name or args.pname or "drv";
        hostPlatform = {system = "x86_64-linux";};
      };
      fish = "fish";
      writeShellScript = name: text: name;
      writeText = name: text: name;
    };
    lib = (import <nixpkgs> {}).lib;
    config = {};
  };
  ds = builtins.head mod.services.grafana.provision.datasources.settings.datasources;
  provider = builtins.head mod.services.grafana.provision.dashboards.settings.providers;
  fleet = builtins.fromJSON (builtins.readFile ./dashboards/fleet.json);
  panelTitles = map (p: p.title) fleet.panels;
in
  assay.suite "grafana" {
    shape = assay.hasAttrs mod ["services"];
    datasourceUidPinned = assay.eq ds.uid "prometheus";
    dashboardProviderReadsDirectory = assay.eq provider.options.path ./dashboards;
    fleetDashboardValidJson = assay.eq fleet.title "Fleet Overview";
    fleetDashboardHasFixedUid = assay.eq fleet.uid "fleet-overview";
    fleetDashboardRefreshes = assay.eq fleet.refresh "10s";
    fleetQueriesUsePinnedDatasource = assay.eq
      (builtins.all (t: t.datasource.uid == "prometheus")
        (builtins.concatMap (p: p.targets or [])
          (builtins.filter (p: p.type != "row") fleet.panels)))
      true;
    fleetCoversEssentials = assay.eq
      (builtins.all
        (t: builtins.elem t panelTitles)
        ["Hosts up" "Load average (1m)" "Memory used" "CPU busy" "Root filesystem used" "Network in" "Network out"])
      true;
    legendsByHostLabel = assay.eq
      (builtins.all (t: t.legendFormat == "{{host}}" || t.legendFormat == "{{host}} {{device}}")
        (builtins.concatMap (p: p.targets or [])
          (builtins.filter (p: p.type != "row") fleet.panels)))
      true;
  }
