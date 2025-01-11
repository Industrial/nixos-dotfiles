# Terminal Session Manager.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [zellij];
    etc = {
      "zellij/config.kdl" = {
        source = ./etc/zellij/config.kdl;
      };
      "zellij/layouts/system.kdl" = {
        source = ./etc/zellij/layouts/system.kdl;
      };
    };
  };
}
