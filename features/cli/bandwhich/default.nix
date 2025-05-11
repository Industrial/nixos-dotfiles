# Bandwhich is a CLI tool for monitoring network connections
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    bandwhich
  ];
}
