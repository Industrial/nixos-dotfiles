# Dust is a tool for cleaning up disk space.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dust
  ];
}
