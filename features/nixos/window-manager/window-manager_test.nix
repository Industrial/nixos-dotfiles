let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "window-manager_test/services.xserver.enable";
    actual = feature.services.xserver.enable;
    expected = true;
  }
  {
    name = "window-manager_test/services.xserver.dpi";
    actual = feature.services.xserver.dpi;
    expected = 96;
  }
  {
    name = "window-manager_test/services.xserver.displayManager.gdm.enable";
    actual = feature.services.xserver.displayManager.gdm.enable;
    expected = true;
  }
  {
    name = "window-manager_test/services.xserver.displayManager.lightdm.enable";
    actual = feature.services.xserver.desktopManager.xfce.enable;
    expected = true;
  }
]
