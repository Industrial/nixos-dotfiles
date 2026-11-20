# Desktop Profile
# Desktop environment and window managers
{
  config,
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  options.profiles.desktop.enable = lib.mkEnableOption "the desktop profile";

  config = lib.mkIf config.profiles.desktop.enable {
    features.desktop.claude-desktop.enable = true;
    features.nixos.window-manager.enable = true;
    features.window-manager.alacritty.enable = true;
    features.window-manager.ghostty.enable = true;
    features.window-manager.gnome.enable = true;
    features.window-manager.hyprland.enable = true;
    features.window-manager.stylix.enable = true;
    features.window-manager.xclip.enable = true;
    features.window-manager.xfce-screenshooter.enable = true;
    features.window-manager.xsel.enable = true;
    profiles.cli-desktop.enable = true;
  };
}
