# Transmission is a BitTorrent client. Port = 9091 (RPC), 51413 (peer).
#
# Uses the native services.transmission module: settings below are merged
# into .config/transmission-daemon/settings.json by the unit's pre-start
# on EVERY start, so there is no symlink/drift machinery to get wrong.
{pkgs, ...}: let
  directoryPath = "/data/services/transmission";
in {
  services.transmission = {
    enable = true;
    # Required since the transmission_3 -> _4 default flip (NixOS 24.11).
    package = pkgs.transmission_4;
    # Settings dir becomes <home>/.config/transmission-daemon.
    home = directoryPath;
    group = "data";
    performanceNetParameters = true;
    openPeerPorts = true;
    settings = {
      download-dir = "${directoryPath}/downloads";
      incomplete-dir = "${directoryPath}/downloads/incomplete";
      incomplete-dir-enabled = true;
      rpc-bind-address = "0.0.0.0";
      # Fleet access by hostname; whitelists would 403 remote clients.
      rpc-host-whitelist-enabled = false;
      rpc-whitelist-enabled = false;
      start-added-torrents = true;
      umask = 2;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${directoryPath} 0770 transmission data - -"
    "d ${directoryPath}/downloads 0770 transmission data - -"
  ];
}
