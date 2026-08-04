# Colocated suite: stylix autoEnable.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      pkgs = {
        callPackage = path: args: "theme";
        noto-fonts-color-emoji = "emoji";
        terminus-nerdfont = "font";
        dejavu_fonts = "dejavu";
        # derivation import needs real-ish stubs via overlaying import path — use fake schemes drv
      } // (
        let
          lib = (import <nixpkgs> {}).lib;
        in {}
      );
      lib = (import <nixpkgs> {}).lib;
    })
  '';
in
  assay.suite "stylix" {
    autoEnable = assay.eq "${mod}.stylix.autoEnable" "true";
  }
