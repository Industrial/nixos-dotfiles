# Assay: the commit-pinned tinted-theming/schemes derivation.
#
# Called the way stylix/default.nix calls it (real pinned pkgs) and projected to its
# attributes; the install phase is a build script, so it is matched as text. The pin itself
# is cross-checked against palette.nix in ../palette.assay.nix.
let
  assay = import ../../../../common/assay/default.nix;
  nixos = import ../../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  pkgs = (nixos.evalSystem {modules = [];}).pkgs;
  drv = (import ./tinted-theming-schemes.nix {inherit pkgs lib;}).tinted-theming-schemes;
in
  assay.suite "tinted-theming-schemes" {
    namesSchemes = assay.eq drv.pname "tinted-theming-schemes";
    tracksSpecVersion = assay.eq drv.version "spec-0.11";
    fetchesUpstreamRepo = assay.eq {inherit (drv.src) owner repo;} {
      owner = "tinted-theming";
      repo = "schemes";
    };
    pinsCommit = assay.eq drv.src.rev "395074124283df993571f2abb9c713f413b76e6e";
    pinsSourceHash = assay.eq drv.src.outputHash "sha256-9LmwYbtTxNFiP+osqRUbOXghJXpYvyvAwBwW80JMO7s=";
    # Only the base16 schemes, flat under share/schemes, where stylix's base16Scheme looks.
    installsBase16YamlToShareSchemes =
      assay.eq (lib.hasInfix "install base16/*.yaml $out/share/schemes/" drv.installPhase) true;
    licenseIsMit = assay.eq drv.meta.license.spdxId "MIT";
    homepageIsTheRepo = assay.eq drv.meta.homepage "https://github.com/tinted-theming/schemes";
  }
