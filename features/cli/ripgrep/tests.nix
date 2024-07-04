args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_systemPackages = {
    expr = builtins.elem pkgs.ripgrep feature.environment.systemPackages;
    expected = true;
  };
}
