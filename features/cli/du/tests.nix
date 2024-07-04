args @ {...}: let
  feature = import ./default.nix args;
in {
  test_systemPackages = {
    expr = builtins.any (pkg: pkg.name == "du" && pkg.version == "1.0") feature.environment.systemPackages;
    expected = true;
  };
}
