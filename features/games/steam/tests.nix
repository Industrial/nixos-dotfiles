args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages_steam = {
    expr = builtins.elem pkgs.steam feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_steam-run = {
    expr = builtins.elem pkgs.steam-run feature.environment.systemPackages;
    expected = true;
  };
}
