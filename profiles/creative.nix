# Creative Profile
# Creative and design tools
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

    # Creative and Design Tools
    ../features/creative/gimp
    ../features/creative/inkscape
    ../features/creative/blender
    ../features/creative/kdenlive
  ];
}
