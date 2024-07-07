args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  # TODO: Test this correctly.
  # test_environment_systemPackages_vscode-with-extensions = {
  #   expr = builtins.elem pkgs.vscode-with-extensions feature.environment.systemPackages;
  #   expected = true;
  # };
  test_environment_systemPackages_alejandra = {
    expr = builtins.elem pkgs.alejandra feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_nixd = {
    expr = builtins.elem pkgs.nixd feature.environment.systemPackages;
    expected = true;
  };
}
