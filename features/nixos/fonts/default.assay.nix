# Colocated suite: fonts.packages selection.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {
      nerd-fonts = {
        iosevka = "nerd-fonts.iosevka";
        "iosevka-term" = "nerd-fonts.iosevka-term";
      };
    };
    mod = import ./default.nix {inherit pkgs;};
  in
    mod.fonts.packages;
in
  assay.suite "fonts" {
    fontPackages = assay.eq mod ["nerd-fonts.iosevka" "nerd-fonts.iosevka-term"];
  }
