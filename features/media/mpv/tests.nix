args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.mpv-unwrapped feature.environment.systemPackages;
    expected = true;
  };
}
