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
    name = "steam_test";
    actual = builtins.elem pkgs.steam feature.environment.systemPackages;
    expected = true;
  }
]
