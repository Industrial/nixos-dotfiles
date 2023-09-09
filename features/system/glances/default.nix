# glances is a system monitor replacing htop
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    glances
  ];
}
