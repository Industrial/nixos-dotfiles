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
    ../features/creative/gimp
    ../features/creative/openpencil
    # ../features/creative/inkscape
    # ../features/creative/blender
    # ../features/creative/kdenlive
  ];
}
