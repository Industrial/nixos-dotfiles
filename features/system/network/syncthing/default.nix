# Syncthing syncs things.
# TODO: settings.username
{
  settings,
  pkgs,
  ...
}: {
  services = {
    syncthing = {
      enable = true;
      user = settings.username;
      dataDir = "${settings.userdir}/Documents";
      configDir = "${settings.userdir}/Documents/.config/syncthing";
    };
  };
}
