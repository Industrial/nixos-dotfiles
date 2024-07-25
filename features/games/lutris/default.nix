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

    lutris
  ];
}
