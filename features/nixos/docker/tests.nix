args @ {...}: let
  feature = import ./default.nix args;
in {
  test_virtualisation_docker_enable = {
    expr = feature.virtualisation.docker.enable;
    expected = true;
  };
}
