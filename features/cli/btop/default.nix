# Btop is a htop replacement
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    btop
  ];
}
