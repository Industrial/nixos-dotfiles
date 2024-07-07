args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages_nodejs = {
    expr = builtins.elem pkgs.nodejs feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_pnpm = {
    expr = builtins.elem pkgs.nodePackages.pnpm feature.environment.systemPackages;
    expected = true;
  };
}
