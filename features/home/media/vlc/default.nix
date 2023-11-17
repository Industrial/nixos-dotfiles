# Video Player.
{pkgs, ...}: {
  home.packages = with pkgs; [
    vlc
  ];
}
