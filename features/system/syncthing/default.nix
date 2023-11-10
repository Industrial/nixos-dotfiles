# Syncthing syncs things.
{pkgs, ...}: {
  services = {
    syncthing = {
      enable = true;
      user = "tom";
      dataDir = "/home/tom/Documents";
      configDir = "/home/tom/Documents/.config/syncthing";
    };
  };
}
