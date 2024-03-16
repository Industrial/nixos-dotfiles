let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.hardware.bluetooth.enable;
    expected = true;
  }
  {
    actual = feature.hardware.bluetooth.settings.General.Enable;
    expected = "Source,Sink,Media,Socket";
  }
  {
    actual = feature.services.blueman.enable;
    expected = true;
  }
]
