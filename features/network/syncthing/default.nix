# Syncthing syncs things.
# http://localhost:8384
{
  settings,
  # pkgs,
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

  # environment = {
  #   systemPackages = with pkgs; [
  #     syncthing
  #   ];
  # };
}
