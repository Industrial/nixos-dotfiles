args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages_docker = {
    expr = builtins.elem pkgs.docker feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_docker-compose = {
    expr = builtins.elem pkgs.docker-compose feature.environment.systemPackages;
    expected = true;
  };
}
