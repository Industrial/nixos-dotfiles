args @ {
  inputs,
  settings,
  pkgs,
  ...
}: {
  eog = import ./eog/tests.nix args;
  invidious = import ./invidious/tests.nix args;
  lxqt-pavucontrol-qt = import ./lxqt-pavucontrol-qt/tests.nix args;
  lxqt-screengrab = import ./lxqt-screengrab/tests.nix args;
  mpv = import ./mpv/tests.nix args;
  obs-studio = import ./obs-studio/tests.nix args;
  okular = import ./okular/tests.nix args;
  spotify = import ./spotify/tests.nix args;
  vlc = import ./vlc/tests.nix args;
}
