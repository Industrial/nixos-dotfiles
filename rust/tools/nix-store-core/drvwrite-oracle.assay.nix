# Colocated suite for drvwrite-oracle.nix, the Nix side of the `.drv` writer's oracle
# (#457, moved from the #417 S1b spike). Evaluates the oracle on the flake.lock's nixpkgs
# and checks that Nix's paths equal the constants src/drvwrite_golden.vlt holds, which
# the Voltaic writer has to reproduce byte for byte. A nixpkgs bump moves them, and then
# the two files move together (with the BASH entry's modulo hash, from drvwrite's
# modulo_of).
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  oracle = import ./drvwrite-oracle.nix {inherit pkgs;};
in
  assay.suite "nix-store-core-drvwrite-oracle" {
    drvPathIsTheWriters = assay.eq oracle.drv "/nix/store/4aadlf2xrqfx10yfkkrzdr7ihbhcnlhy-s1b-hello.drv";
    outPathIsTheWriters = assay.eq oracle.out "/nix/store/p65cg6592lrxg822n2inhxlbvdjazy3z-s1b-hello";

    # The package-index entry (BASH in src/drvwrite_golden.vlt) names the same bash.
    bashIsTheIndexed = assay.eq oracle.bashDrv "/nix/store/kflvs7jxvlz0ipa80jxkn0dpgngnn53s-bash-interactive-5.3p20.drv";
  }
