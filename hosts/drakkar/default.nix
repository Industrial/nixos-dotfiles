{pkgs, ...}: {
  imports = [
    ../common/boot.nix
    ../common/console.nix
    ../common/docker.nix
    ../common/fonts.nix
    ../common/gnome.nix
    ../common/graphics.nix
    ../common/i18n.nix
    ../common/networking.nix
    ../common/nix.nix
    ../common/nixpkgs.nix
    ../common/printing.nix
    ../common/security.nix
    ../common/shell.nix
    ../common/sound.nix
    ../common/time.nix
    ./hardware-configuration.nix
  ];

  networking = {
    hostName = "drakkar";
  };

  environment = {
    systemPackages = with pkgs; [
      # Sound
      helvum
      pavucontrol

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

      # NTLM Support for wine
      samba

      lutris
    ];
  };

  system = {
    stateVersion = "23.05";
  };
}
