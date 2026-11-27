# The oracle for src/drvwrite_golden.vlt: the derivation that test emits,
# instantiated by Nix on the nixpkgs this repository pins.
# drvwrite-oracle.assay.nix evaluates it with the flake.lock's nixpkgs and checks
# the paths that src/drvwrite_golden.vlt expects.
{pkgs}: let
  d = derivation {
    name = "s1b-hello";
    system = "x86_64-linux";
    builder = "${pkgs.bash}/bin/bash";
    args = [
      "-c"
      "echo \"hi\" > $out"
    ];
  };
in {
  drv = d.drvPath;
  out = d.outPath;
  bashDrv = pkgs.bash.drvPath;
  bashOut = pkgs.bash.outPath;
}
