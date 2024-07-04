args @ {settings, ...}: let
  feature = import ./default.nix args;
in {
  test_enable = {
    expr = feature.services.syncthing.enable;
    expected = true;
  };
  test_user = {
    expr = feature.services.syncthing.user;
    expected = settings.username;
  };
  test_dataDir = {
    expr = feature.services.syncthing.dataDir;
    expected = "${settings.userdir}/Documents";
  };
  test_configDir = {
    expr = feature.services.syncthing.configDir;
    expected = "${settings.userdir}/Documents/.config/syncthing";
  };
}
