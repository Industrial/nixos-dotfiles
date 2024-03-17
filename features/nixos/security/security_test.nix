let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "security_test";
    actual = feature.security.sudo.enable;
    expected = true;
  }
  {
    name = "security_test";
    actual = feature.security.sudo.wheelNeedsPassword;
    expected = true;
  }
  {
    name = "security_test";
    actual = feature.security.sudo.execWheelOnly;
    expected = true;
  }
]
