args @ {
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix args;
in {
  nix-daemon = import ./nix-daemon/tests.nix args;
  nix-unit = import ./nix-unit/tests.nix args;
  nixpkgs = import ./nixpkgs/tests.nix args;

  test_system_stateVersion = {
    expr = feature.system.stateVersion == settings.stateVersion;
    expected = true;
  };

  test_system_packages = {
    expr = feature.nix.package == pkgs.nixFlakes;
    expected = true;
  };

  test_experimental_features = {
    expr = feature.nix.settings.experimental-features == "nix-command flakes";
    expected = true;
  };

  test_allow_import_from_derivation = {
    expr = feature.nix.settings.allow-import-from-derivation;
    expected = true;
  };
}
