{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    kdenlive
    ffmpeg
    mediainfo
    mkvtoolnix
    handbrake
  ];
}
