# File Manager.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    ranger
  ];
}
