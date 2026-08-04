# Colocated suite: zellij packages (fetchurl stubbed).
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "u";
    };
    pkgs = {
      zellij = "zellij";
      wl-clipboard = "wl-clipboard";
      fetchurl = args: "wasm";
      writeText = name: text: name;
    };
  };
in
  assay.suite "zellij" {
    packages = assay.eq mod.environment.systemPackages ["zellij" "wl-clipboard"];
  }
