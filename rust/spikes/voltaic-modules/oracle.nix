# The oracle for host/src/oracle.vlt: the same derivation as the spike host's
# toplevel, instantiated by Nix on the nixpkgs this repository pins.
# oracle.assay.nix evaluates it with the flake.lock's nixpkgs and checks the
# paths that host/src/oracle.vlt expects.
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
