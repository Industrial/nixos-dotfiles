# Video Player.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    vlc
  ];
}
