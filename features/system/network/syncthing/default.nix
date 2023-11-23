# Syncthing syncs things.
# TODO: c9config.username
{c9config, pkgs, ...}: {
  services = {
    syncthing = {
      enable = true;
      user = c9config.username;
      dataDir = "${c9config.userdir}/Documents";
      configDir = "${c9config.userdir}/Documents/.config/syncthing";
    };
  };
}
