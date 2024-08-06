args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages_python312 = {
    expr = builtins.elem pkgs.python312 feature.environment.systemPackages;
    expected = true;
  };
}
