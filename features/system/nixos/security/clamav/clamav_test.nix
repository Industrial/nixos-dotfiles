let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "clamav_test";
    actual = feature.services.clamav.daemon.enable;
    expected = true;
  }
  {
    name = "clamav_test";
    actual = feature.services.clamav.updater.enable;
    expected = true;
  }
  {
    name = "clamav_test";
    actual = feature.services.clamav.scanner.enable;
    expected = true;
  }
  {
    name = "clamav_test";
    actual = feature.services.clamav.scanner.interval;
    expected = "Weekly Sunday 12:00:00";
  }
]
