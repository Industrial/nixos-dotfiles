# Communication Profile
# Communication applications
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    ../features/communication/discord
    # ../features/communication/fractal
    ../features/communication/signal-desktop
    # ../features/communication/teams
    # ../features/communication/telegram
    # ../features/communication/weechat
  ];
}
