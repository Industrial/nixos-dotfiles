# World of Warcraft Classic configuration management
# Manages WTF (settings) and Interface (AddOns) directories via symlinks
# USAGE: Run `bin/wow link` to create symlinks from dotfiles to WoW installation
# This must be done manually after each fresh install or if symlinks are broken
{
  pkgs,
  settings,
  ...
}: let
  linkWowClassic = pkgs.writeShellScriptBin "link-wow-classic" ''
    ${builtins.readFile ./bin/link-wow-classic}
  '';
in {
  environment.systemPackages = [
    linkWowClassic
  ];

  # Note: Symlinks are created manually via `bin/wow link` script
  # This approach is similar to the cursor feature and allows for:
  # - Manual control over when symlinks are created
  # - Easier troubleshooting
  # - No conflicts with Wine prefix permissions
  # - Works even if WoW path doesn't exist at build time
}
