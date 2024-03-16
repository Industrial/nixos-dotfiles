let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.services.clamav.daemon.enable;
    expected = true;
  }
  {
    actual = feature.services.clamav.updater.enable;
    expected = true;
  }
  {
    actual = feature.services.clamav.scanner.enable;
    expected = true;
  }
  {
    actual = feature.services.clamav.scanner.interval;
    expected = "Weekly Sunday 12:00:00";
  }
]
