# Gping is a ping tool that supports multiple hosts
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gping
  ];
}
