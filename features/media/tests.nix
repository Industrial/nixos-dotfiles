args @ {...}: {
  invidious = import ./invidious/tests.nix args;
  lidarr = import ./lidarr/tests.nix args;
  okular = import ./okular/tests.nix args;
  radarr = import ./radarr/tests.nix args;
  spotify = import ./spotify/tests.nix args;
  transmission = import ./transmission/tests.nix args;
  vlc = import ./vlc/tests.nix args;
}
