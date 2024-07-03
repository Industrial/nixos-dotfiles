{
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix {inherit inputs pkgs settings;};
in {
  test_systemPackages = {
    expr = builtins.any (pkg: pkg.name == "cheatsheet" && pkg.version == "1.0") feature.environment.systemPackages;
    expected = true;
  };
}
