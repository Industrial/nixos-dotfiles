# Video Player.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    vlc
  ];
}
