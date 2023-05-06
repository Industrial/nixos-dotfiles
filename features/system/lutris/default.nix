{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    (wineWowPackages.staging.override {
      wineRelease = "staging";
      gettextSupport = true;
      fontconfigSupport = true;
      alsaSupport = true;
      gtkSupport = true;
      openglSupport = true;
      tlsSupport = true;
      gstreamerSupport = true;
      openclSupport = true;
      udevSupport = true;
      vulkanSupport = true;
      mingwSupport = true;
      pulseaudioSupport = true;
    })
    winetricks

    lutris-unwrapped

    # NTLM Support for wine (Path of Building)
    samba

    # Beyond All Reason
    #openal
    #xdg-desktop-portal-gtk

    #xdg.portal.enable = true;
    #xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
    #services.flatpak.enable = true;
  ];
}
