{
  pkgs,
  inputs,
  ...
}: let
  assayPkg = pkgs.callPackage inputs.assay-src {};
in {
  environment.systemPackages = with pkgs; [
    assayPkg
  ];
}
