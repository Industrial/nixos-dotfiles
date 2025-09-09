{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    kdePackages.kdenlive
    ffmpeg
    mediainfo
    mkvtoolnix
    handbrake
  ];
}
