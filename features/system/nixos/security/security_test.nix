let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.security.sudo.enable;
    expected = true;
  }
  {
    actual = feature.security.sudo.wheelNeedsPassword;
    expected = true;
  }
  {
    actual = feature.security.sudo.execWheelOnly;
    expected = true;
  }
]
