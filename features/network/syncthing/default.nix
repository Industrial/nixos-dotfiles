# Syncthing syncs things.
{settings, ...}: {
  services.syncthing.enable = true;
  services.syncthing.user = settings.username;
  services.syncthing.dataDir = "${settings.userdir}/Documents";
  services.syncthing.configDir = "${settings.userdir}/Documents/.config/syncthing";
}
