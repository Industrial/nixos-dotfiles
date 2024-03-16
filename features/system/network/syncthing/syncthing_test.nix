let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.services.syncthing.enable;
    expected = true;
  }
  {
    actual = feature.services.syncthing.user;
    expected = settings.username;
  }
  {
    actual = feature.services.syncthing.dataDir;
    expected = "${settings.userdir}/Documents";
  }
  {
    actual = feature.services.syncthing.configDir;
    expected = "${settings.userdir}/Documents/.config/syncthing";
  }
]
