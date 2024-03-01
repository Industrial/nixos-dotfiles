# Music Library & Player.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    spotify
  ];
}
