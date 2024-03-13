# Chat.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    discord
  ];
}
