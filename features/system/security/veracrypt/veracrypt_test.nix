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
    name = "veracrypt_test";
    actual = builtins.elem pkgs.veracrypt feature.environment.systemPackages;
    expected = true;
  }
]
