{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # (wineWow64Packages.waylandFull.override {
    #   wineRelease = "staging";
    #   gettextSupport = true;
    #   fontconfigSupport = true;
    #   alsaSupport = true;
    #   gtkSupport = true;
    #   openglSupport = true;
    #   tlsSupport = true;
    #   gstreamerSupport = true;
    #   openclSupport = true;
    #   udevSupport = true;
    #   vulkanSupport = true;
    #   mingwSupport = true;
    #   pulseaudioSupport = true;
    # })
    wineWow64Packages.fonts
    winetricks

    # bottles
    # heroic
    lutris
    protonup-qt
    vulkan-tools
  ];

  programs = {
    gamemode = {
      enable = true;
    };

    steam = {
      enable = true;
    };
  };
}
