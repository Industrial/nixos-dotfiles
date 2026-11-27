# Colocated suite for rust/spikes/voltaic-modules/oracle.nix, the Nix side of
# the #417 S1b .drv oracle. Evaluates the oracle on the flake.lock's nixpkgs
# and checks that Nix's paths equal the constants host/src/oracle.vlt holds,
# which the spike's Voltaic emitter has to reproduce byte for byte. A
# nixpkgs bump moves them, and then the two files move together (and
# host/src/pkgs.vlt is regenerated with gen-index).
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  oracle = import ./oracle.nix {inherit pkgs;};
in
  assay.suite "voltaic-modules-oracle" {
    drvPathIsTheSpikes = assay.eq oracle.drv "/nix/store/4aadlf2xrqfx10yfkkrzdr7ihbhcnlhy-s1b-hello.drv";
    outPathIsTheSpikes = assay.eq oracle.out "/nix/store/p65cg6592lrxg822n2inhxlbvdjazy3z-s1b-hello";

    # The package index (host/src/pkgs.vlt) names the same bash.
    bashIsTheIndexed = assay.eq oracle.bashDrv "/nix/store/kflvs7jxvlz0ipa80jxkn0dpgngnn53s-bash-interactive-5.3p20.drv";
  }
