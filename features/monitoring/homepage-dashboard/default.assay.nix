# Colocated suite: homepage-dashboard module with stubbed deps.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {settings.hostname = "mimir";};
  hp = mod.services.homepage-dashboard;
in
  assay.suite "homepage-dashboard" {
    enabled = assay.eq hp.enable true;
    listenPort = assay.eq hp.listenPort 8083;
    titleSet = assay.eq (hp.settings ? "title") true;
    servicesDeclared = assay.eq ((builtins.length hp.services) > 0) true;
    widgetsDeclared = assay.eq ((builtins.length hp.widgets) > 0) true;
  }
