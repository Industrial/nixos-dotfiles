let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem pkgs.nodejs feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.nodePackages.pnpm feature.environment.systemPackages;
    expected = true;
  }
]
