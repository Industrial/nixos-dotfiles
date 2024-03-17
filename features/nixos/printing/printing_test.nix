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
    name = "printing_test";
    actual = feature.services.printing.enable;
    expected = true;
  }
  {
    name = "printing_test";
    actual = builtins.elem pkgs.cnijfilter2 feature.environment.systemPackages;
    expected = true;
  }
]
