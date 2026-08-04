# Colocated suite: fonts.packages selection.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = { nerd-fonts = { iosevka = "nerd-fonts.iosevka"; "iosevka-term" = "nerd-fonts.iosevka-term"; }; };
      mod = import ${modFile} { inherit pkgs; };
    in mod.fonts.packages)
'';
in
  assay.suite "fonts" {
    fontPackages = assay.eq packages ''[ "nerd-fonts.iosevka" "nerd-fonts.iosevka-term" ]'';
  }
