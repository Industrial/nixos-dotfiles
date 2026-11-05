# Ghostty is a GPU-accelerated terminal emulator. It sits beside Alacritty
# rather than replacing it: Alacritty keeps SUPER+Return, Ghostty answers to
# SUPER+SHIFT+Return, so the fleet can try it without betting the default
# terminal on it.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    ghostty
  ];

  # Activation script names share one namespace across every feature, so this
  # one is named for its feature rather than the generic `linkFile`, which
  # features/window-manager/alacritty already defines.
  system.activationScripts.linkGhosttyConfig = {
    text = ''
      mkdir -p ${settings.userdir}/.config/ghostty
      ln -sf ${pkgs.writeTextFile {
        name = "config.ghostty";
        text = builtins.readFile ./.config/ghostty/config.ghostty;
      }} ${settings.userdir}/.config/ghostty/config.ghostty
    '';
  };
}
