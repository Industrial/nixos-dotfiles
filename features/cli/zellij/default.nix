# Terminal Session Manager.
{
  settings,
  pkgs,
  ...
}: let
  zjstatus-hints = pkgs.fetchurl {
    url = "https://github.com/b0o/zjstatus-hints/releases/latest/download/zjstatus-hints.wasm";
    hash = "sha256-k2xV6QJcDtvUNCE4PvwVG9/ceOkk+Wa/6efGgr7IcZ0=";
  };
in {
  environment = {
    systemPackages = with pkgs; [
      zellij
      wl-clipboard # Wayland clipboard support for zellij
    ];
    etc = {
      "zellij/config.kdl" = {
        source = ./etc/zellij/config.kdl;
      };
      "zellij/layouts/system.kdl" = {
        source = ./etc/zellij/layouts/system.kdl;
      };
      "zellij/plugins/zjstatus-hints.wasm" = {
        source = zjstatus-hints;
      };
    };
  };

  system = {
    activationScripts = {
      linkZellijConfig = {
        text = ''
          mkdir -p /home/${settings.username}/.config/zellij/layouts
          mkdir -p /home/${settings.username}/.config/zellij/plugins
          ln -sf /etc/zellij/config.kdl /home/${settings.username}/.config/zellij/config.kdl
          ln -sf /etc/zellij/layouts/system.kdl /home/${settings.username}/.config/zellij/layouts/system.kdl
          ln -sf /etc/zellij/plugins/zjstatus-hints.wasm /home/${settings.username}/.config/zellij/plugins/zjstatus-hints.wasm
        '';
      };
    };
  };
}
