args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.git feature.environment.systemPackages;
    expected = true;
  };
  test_environment_etc_gitconfig = {
    expr = builtins.hasAttr "gitconfig" feature.environment.etc;
    expected = true;
  };
}
