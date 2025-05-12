# Terminal Spotify Player
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    spotify-player
  ];
}
