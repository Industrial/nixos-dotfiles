# Colocated suite: module options, not a package list. The nixpkgs direnv
# module owns installation, so there is nothing in systemPackages to assert on.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {};
in
  assay.suite "direnv" {
    shape = assay.hasAttrs mod.programs ["direnv"];

    enabled = assay.eq mod.programs.direnv.enable true;

    # The eval cache is the whole point of the options form; if this ever goes
    # false, every cd into a devenv/flake project pays a full re-evaluation.
    nixDirenvEnabled = assay.eq mod.programs.direnv.nix-direnv.enable true;

    # programs.direnv.enable already adds cfg.package to systemPackages.
    # Declaring pkgs.direnv here as well would install it a second time.
    declaresNoSystemPackages = assay.eq (mod ? environment) false;
  }
