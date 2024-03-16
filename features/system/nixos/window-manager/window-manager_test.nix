let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "window-manager_test";
    actual = feature.services.xserver.enable;
    expected = true;
  }
  {
    name = "window-manager_test";
    actual = feature.services.xserver.dpi;
    expected = 96;
  }
  {
    name = "window-manager_test";
    actual = feature.services.xserver.displayManager.startx.enable;
    expected = false;
  }
  {
    name = "window-manager_test";
    actual = feature.services.xserver.displayManager.gdm.enable;
    expected = true;
  }
  {
    name = "window-manager_test";
    actual = feature.services.xserver.displayManager.lightdm.enable;
    expected = false;
  }
  {
    name = "window-manager_test";
    actual = feature.services.xserver.desktopManager.xfce.enable;
    expected = true;
  }
  {
    name = "window-manager_test";
    actual = feature.environment.systemPackages;
    expected = with pkgs; [
      xorg.xinit
    ];
  }
]
