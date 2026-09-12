# World of Warcraft Classic configuration management
# Manages WTF (settings) and Interface (AddOns) directories via symlinks
{
  config,
  lib,
  settings,
  ...
}: let
  wowClassicPath = "/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_";
  dotfilesWowPath = "${config.home.homeDirectory}/.dotfiles/features/games/wow-classic";
in {
  # Symlink WTF directory (all settings, saved variables, account data)
  # Using out-of-store symlink so WoW can write to these files
  home.file."${wowClassicPath}/WTF" = lib.mkIf (builtins.pathExists wowClassicPath) {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWowPath}/WTF";
    recursive = true;
  };

  # Symlink Interface directory (AddOns)
  home.file."${wowClassicPath}/Interface" = lib.mkIf (builtins.pathExists wowClassicPath) {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWowPath}/Interface";
    recursive = true;
  };

  # Alternative approach: Individual AddOn management
  # Uncomment if you prefer to track specific AddOns rather than the whole directory
  # home.file."${wowClassicPath}/Interface/AddOns/MyAddon" = {
  #   source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWowPath}/Interface/AddOns/MyAddon";
  #   recursive = true;
  # };
}
