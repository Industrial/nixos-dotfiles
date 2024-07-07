args @ {
  pkgs,
  settings,
  ...
}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.alacritty feature.environment.systemPackages;
    expected = true;
  };
  test_system_activationScripts_linkFile_text = {
    expr = feature.system.activationScripts.linkFile.text;
    expected = ''
      mkdir -p /home/${settings.username}/.config/alacritty
      ln -sf ${pkgs.writeTextFile {
        name = "alacritty.toml";
        text = builtins.readFile ./.config/alacritty/alacritty.toml;
      }} /home/${settings.username}/.config/alacritty/alacritty.toml
    '';
  };
}
