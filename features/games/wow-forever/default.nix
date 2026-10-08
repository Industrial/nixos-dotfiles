# World of Warcraft Forever configuration management
# Manages WTF (settings) and Interface (AddOns) directories via symlinks
# USAGE: Run `link-wow-forever` to create symlinks from dotfiles to WoW installation
# This must be done manually after each fresh install or if symlinks are broken
{
  pkgs,
  settings,
  ...
}: let
  linkWowForever = pkgs.writeShellScriptBin "link-wow-forever" ''
    ${builtins.readFile ./bin/link-wow-forever}
  '';
in {
  environment.systemPackages = [
    linkWowForever
  ];

  # Note: Symlinks are created manually via `link-wow-forever` script
  # This approach is similar to the cursor feature and allows for:
  # - Manual control over when symlinks are created
  # - Easier troubleshooting
  # - No conflicts with Wine prefix permissions
  # - Works even if WoW path doesn't exist at build time
}
