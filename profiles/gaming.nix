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
    ./base.nix

    # Games
    ../features/games/lutris
    ../features/games/path-of-building
    ../features/games/wowup
  ];
}
