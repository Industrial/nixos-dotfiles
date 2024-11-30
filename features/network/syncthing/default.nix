# Syncthing syncs things.
# http://localhost:8384
{
  settings,
  # pkgs,
  ...
}: {
  services = {
    syncthing = {
      configDir = "${settings.userdir}/Documents/.config/syncthing";
      dataDir = "${settings.userdir}/Documents";
      enable = true;
      guiAddress = "${settings.hostname}:8384";
      user = settings.username;
    };
  };

  # environment = {
  #   systemPackages = with pkgs; [
  #     syncthing
  #   ];
  # };
}
