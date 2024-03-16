let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "zsa-keyboard_test";
    actual = builtins.elem pkgs.wally-cli feature.environment.systemPackages;
    expected = true;
  }
  {
    name = "zsa-keyboard_test";
    actual = feature.hardware.keyboard.zsa.enable;
    expected = true;
  }
]
