# Screen Recorder and Streamer.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    obs-studio
  ];
}
