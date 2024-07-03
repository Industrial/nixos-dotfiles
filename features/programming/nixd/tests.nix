let
  pkgs = import <nixpkgs> {
    config = {
      allowUnfree = true;
    };
  };
  settings = import ../../../hosts/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    expr = builtins.elem pkgs.nixd feature.environment.systemPackages;
    expected = true;
  }
]
