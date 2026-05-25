# pi-plugin-goal — Pi plugin for goal management
{pkgs}:
  pkgs.writeShellScriptBin "pi-plugin-goal" ''
    exec "$HOME/.dotfiles/features/ai/pi/bin/pi-plugin-goal" "$@"
  ''
