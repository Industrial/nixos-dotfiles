{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    alacritty
  ];

  system.activationScripts.linkFile = {
    text = ''
      mkdir -p /home/${settings.username}/.config/alacritty
      ln -sf ${pkgs.writeTextFile {
        name = "alacritty.toml";
        text = builtins.readFile ./.config/alacritty/alacritty.toml;
      }} /home/${settings.username}/.config/alacritty/alacritty.toml
    '';
  };
}
