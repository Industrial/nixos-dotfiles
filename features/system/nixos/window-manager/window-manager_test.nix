let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.services.xserver.enable;
    expected = true;
  }
  {
    actual = feature.services.xserver.dpi;
    expected = 96;
  }
  {
    actual = feature.services.xserver.displayManager.startx.enable;
    expected = false;
  }
  {
    actual = feature.services.xserver.displayManager.gdm.enable;
    expected = true;
  }
  {
    actual = feature.services.xserver.displayManager.lightdm.enable;
    expected = false;
  }
  {
    actual = feature.services.xserver.desktopManager.xfce.enable;
    expected = true;
  }
  {
    actual = feature.environment.systemPackages;
    expected = with pkgs; [
      xorg.xinit
    ];
  }
]
