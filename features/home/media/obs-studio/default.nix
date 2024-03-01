# Screen Recorder and Streamer.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    obs-studio
  ];
}
