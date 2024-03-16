let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem pkgs.alacritty feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = feature.system.activationScripts.linkFile.text;
    expected = ''
      mkdir -p /home/${settings.username}/.config/alacritty
      ln -sf ${pkgs.writeTextFile {
        name = "alacritty.toml";
        text = builtins.readFile ./.config/alacritty/alacritty.toml;
      }} /home/${settings.username}/.config/alacritty/alacritty.toml
    '';
  }
]
