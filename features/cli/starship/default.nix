# Prompt.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    starship
  ];

  # Activation script names share one namespace across every feature, so this
  # one is named for its feature rather than the generic `linkFile`, which
  # features/window-manager/alacritty already defines.
  system.activationScripts.linkStarshipConfig = {
    text = ''
      mkdir -p ${settings.userdir}/.config
      ln -sf ${pkgs.writeTextFile {
        name = "starship.toml";
        text = builtins.readFile ./starship.toml;
      }} ${settings.userdir}/.config/starship.toml
    '';
  };
}
