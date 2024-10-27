# Terminal Session Manager.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [zellij];
  environment.etc."zellij/config.kdl".source = ./etc/zellij/config.kdl;
  environment.etc."zellij/layouts/system.kdl".source = ./etc/zellij/layouts/system.kdl;
}
