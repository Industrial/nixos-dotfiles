let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "time_test";
    actual = feature.time.timeZone;
    expected = "Europe/Amsterdam";
  }
]
