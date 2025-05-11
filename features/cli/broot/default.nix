# Broot is a file manager for the terminal
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    broot
  ];
}
