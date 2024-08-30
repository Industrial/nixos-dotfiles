args @ {...}: let
  feature = import ./default.nix args;
  name = "create-ssh-key";
in {
  test_environment_systemPackages = {
    expr = builtins.any (pkg: pkg.name == name && pkg.version == "1.0") feature.environment.systemPackages;
    expected = true;
  };
}
