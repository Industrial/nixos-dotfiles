# Colocated suite: nushell on systemPackages + config activation.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
    pkgs = {nushell = "nushell";};
  };
in
  assay.suite "nushell" {
    packages = assay.eq mod.environment.systemPackages ["nushell"];
    linksConfigOnActivate = assay.eq (builtins.match ".*linkNushellConfig.*" src != null) true;
  }
