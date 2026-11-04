# Ghostty is a GPU-accelerated terminal emulator.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    ghostty
  ];
}
