args @ {...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages = {
    expr = builtins.any (pkg: pkg.name == "l" && pkg.version == "1.0") feature.environment.systemPackages;
    expected = true;
  };
}
