# Colocated suite: jackett via the native services.jackett module.
# The module needs full nixpkgs (mkPackageOption, config.ids), so this
# suite asserts our option VALUES as a plain attrset contract instead of
# importing the module — eval of the real module happens in the mimir
# toplevel build gate.
let
  assay = import ./../../../common/assay/default.nix;
  opts = {
    services.jackett = {
      enable = true;
      port = 9117;
      dataDir = "/data/services/jackett";
      group = "data";
    };
  };
in
  assay.suite "jackett" {
    enabled = assay.eq opts.services.jackett.enable true;
    port9117 = assay.eq opts.services.jackett.port 9117;
    dataDirOnNfsVolume = assay.eq
      opts.services.jackett.dataDir "/data/services/jackett";
    groupDataForNfs = assay.eq opts.services.jackett.group "data";
  }
