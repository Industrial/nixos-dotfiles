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
    actual = builtins.elem pkgs.git feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.hasAttr "gitconfig" feature.environment.etc;
    expected = true;
  }
]
