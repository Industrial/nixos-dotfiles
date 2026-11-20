# Creative Profile
# Creative and design tools
{
  config,
  lib,
  ...
}: {
  options.profiles.creative.enable = lib.mkEnableOption "the creative profile";

  config = lib.mkIf config.profiles.creative.enable {
    features.creative.gimp.enable = true;
    features.creative.openpencil.enable = true;
    features.creative.obs-studio.enable = true;
    # features.creative.inkscape.enable = true;
    # features.creative.blender.enable = true;
    # features.creative.kdenlive.enable = true;
  };
}
