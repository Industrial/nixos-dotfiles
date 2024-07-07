args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.tor-browser-bundle-bin feature.environment.systemPackages;
    expected = true;
  };
}
