# Colocated suite for features/monitoring/prometheus/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  mod = import ./default.nix {
    settings = {hostname = "test-host";};
  };
  scrape = builtins.head mod.services.prometheus.scrapeConfigs;
in
  assay.suite "prometheus" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
    nodesJobPresent = assay.eq scrape.job_name "nodes";
    oneSecondScrape = assay.eq scrape.scrape_interval "1s";
    allHostsLabeled =
      assay.eq
      (map (c: c.labels.host) scrape.static_configs)
      ["test-host" "mimir" "drakkar" "huginn" "muninn"];
  }
