{
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix {inherit inputs pkgs settings;};
in {
  test_systemPackages = {
    expr = builtins.elem pkgs.appimage-run feature.environment.systemPackages;
    expected = true;
  };
}
