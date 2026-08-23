# Colocated suite for features/monitoring/prometheus-exporter/default.nix.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    config = {};
    lib = {};
    pkgs = {};
  };
  node = mod.services.prometheus.exporters.node;
  toSet = cs: builtins.listToAttrs (map (c: {name = c; value = true;}) cs);
  enabledSet = toSet node.enabledCollectors;
  disabledSet = toSet node.disabledCollectors;
  # Collectors listed on both sides would silently win whichever way the
  # module merges them — they must be disjoint.
  overlap = builtins.filter (c: enabledSet ? ${c}) node.disabledCollectors;
in
  assay.suite "prometheus-exporter" {
    exporterEnabled = assay.eq node.enable true;
    scrapePort = assay.eq node.port 9002;
    coreCollectorsOn = assay.subset enabledSet {
      cpu = true;
      meminfo = true;
      systemd = true;
      filesystem = true;
      netdev = true;
    };
    enabledDisabledDisjoint = assay.eq overlap [];
    disabledSetsNonEmpty = assay.eq
      (builtins.length node.disabledCollectors > 0)
      true;
  }
