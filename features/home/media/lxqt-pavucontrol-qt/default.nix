# Pavucontrol is a simple GTK based volume control tool ("mixer") for the
# PulseAudio sound server.
# TODO: When I start this, it's not tiled/fullscreen but floating. Try to get
#       this window to tile.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    lxqt.pavucontrol-qt
  ];
}
