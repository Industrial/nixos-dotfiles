# Dysk is a tool for managing disk space.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dysk
  ];
}
