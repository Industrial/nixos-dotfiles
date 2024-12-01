# A Fast, Easy and Free Bittorrent Client For macOS, Windows and Linux.
# This feature is set up to run on my server, huginn, which happens to be a
# tablet. The Data directory is an SD Card.
{
  settings,
  pkgs,
  ...
}: let
  username = "transmission";
  homeDirectoryPath = "/home/${username}";
  dataDirectoryPath = "/run/media/${settings.username}/Data";
in {
  environment.systemPackages = with pkgs; [
    transmission_4
    transmission_4-qt
  ];

  services = {
    "${username}" = {
      enable = true;
      package = pkgs.transmission_4;
      user = "${username}";
      group = pkgs.lib.mkForce "data";
      home = homeDirectoryPath;
      openFirewall = false;
      openPeerPorts = false;
      openRPCPort = false;
      downloadDirPermissions = "770";
      # Alternative Web Interface
      webHome = pkgs.flood-for-transmission;
      settings = {
        download-dir = "${dataDirectoryPath}/transmission/downloads";
        incomplete-dir = "${dataDirectoryPath}/transmission/incomplete";
        incomplete-dir-enabled = true;
        watch-dir = "${dataDirectoryPath}/transmission/watch";
        watch-dir-enabled = true;
      };
    };
  };

  users = {
    users = {
      "${username}" = {
        isSystemUser = true;
        home = homeDirectoryPath;
        createHome = true;
        group = pkgs.lib.mkForce "${username}";
        extraGroups = ["data"];
      };
    };
    groups = {
      "${username}" = {};
    };
  };
}
