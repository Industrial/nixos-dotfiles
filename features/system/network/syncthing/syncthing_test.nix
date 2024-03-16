let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "syncthing_test";
    actual = feature.services.syncthing.enable;
    expected = true;
  }
  {
    name = "syncthing_test";
    actual = feature.services.syncthing.user;
    expected = settings.username;
  }
  {
    name = "syncthing_test";
    actual = feature.services.syncthing.dataDir;
    expected = "${settings.userdir}/Documents";
  }
  {
    name = "syncthing_test";
    actual = feature.services.syncthing.configDir;
    expected = "${settings.userdir}/Documents/.config/syncthing";
  }
]
