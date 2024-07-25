# Screen Recorder and Streamer.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    obs-studio
  ];
}
