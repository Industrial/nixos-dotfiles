let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "fzf_test";
    actual = builtins.elem pkgs.fzf feature.environment.systemPackages;
    expected = true;
  }
]
