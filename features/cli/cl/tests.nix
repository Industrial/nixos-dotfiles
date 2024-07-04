args @ {...}: let
  feature = import ./default.nix args;
in {
  test_systemPackages = {
    expr = builtins.any (pkg: pkg.name == "cl" && pkg.version == "1.0") feature.environment.systemPackages;
    expected = true;
  };
}
