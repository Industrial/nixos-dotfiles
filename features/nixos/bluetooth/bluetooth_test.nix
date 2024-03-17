let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "bluetooth_test";
    actual = feature.hardware.bluetooth.enable;
    expected = true;
  }
  {
    name = "bluetooth_test";
    actual = feature.hardware.bluetooth.settings.General.Enable;
    expected = "Source,Sink,Media,Socket";
  }
  {
    name = "bluetooth_test";
    actual = feature.services.blueman.enable;
    expected = true;
  }
]
