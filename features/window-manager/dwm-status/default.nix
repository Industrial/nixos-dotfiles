# Make the dwm-status tool available in the system.
{
  pkgs,
  inputs,
  ...
}: let
  dwmStatusPkg = pkgs.callPackage inputs.dwm-status-src {};
in {
  environment.systemPackages = [dwmStatusPkg];
}
