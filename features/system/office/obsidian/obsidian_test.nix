let
  pkgs = import <nixpkgs> {
    config = {
      allowUnfree = true;
    };
  };
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem pkgs.obsidian feature.environment.systemPackages;
    expected = true;
  }
]
