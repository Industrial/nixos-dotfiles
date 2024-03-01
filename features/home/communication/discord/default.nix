# Chat.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    discord
  ];
}
