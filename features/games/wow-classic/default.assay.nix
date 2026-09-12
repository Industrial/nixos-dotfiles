# Colocated suite: WoW Classic configuration
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    writeShellScriptBin = name: text: {inherit name text;};
  };
  settings = {
    hostname = "h";
    username = "alice";
  };
  mod = import ./default.nix {inherit pkgs settings;};
in
  assay.suite "wow-classic" {
    has-link-script = assay.eq (builtins.hasAttr "environment" mod && builtins.hasAttr "systemPackages" mod.environment) true;
    packages-non-empty = assay.eq (builtins.length mod.environment.systemPackages > 0) true;
  }
