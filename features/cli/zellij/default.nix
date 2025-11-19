# Terminal Session Manager.
{
  settings,
  pkgs,
  ...
}: {
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

  system = {
    activationScripts = {
      linkZellijConfig = {
        text = ''
          mkdir -p /home/${settings.username}/.config/zellij/layouts
          ln -sf /etc/zellij/config.kdl /home/${settings.username}/.config/zellij/config.kdl
          ln -sf /etc/zellij/layouts/system.kdl /home/${settings.username}/.config/zellij/layouts/system.kdl
        '';
      };
    };
  };
}
