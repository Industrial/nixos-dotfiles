# Colocated suite: nushell on systemPackages.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
    };
    pkgs = {nushell = "nushell";};
  };
in
  assay.suite "nushell" {
    packages = assay.eq mod.environment.systemPackages ["nushell"];
  }
