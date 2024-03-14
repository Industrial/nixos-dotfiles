# Music Library & Player.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    spotify
  ];
}
