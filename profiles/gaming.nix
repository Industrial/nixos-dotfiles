# Gaming Profile
# Gaming tools and applications
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    ../features/games/appimage
    ../features/games/awakened-poe-trade
    ../features/games/exiled-exchange-2
    ../features/games/lutris
    ../features/games/path-of-building
    ../features/games/wow-classic
    ../features/games/wowup
  ];
}
