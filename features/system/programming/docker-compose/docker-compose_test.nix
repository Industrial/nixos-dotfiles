let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "docker-compose_test";
    actual = builtins.elem pkgs.docker-compose feature.environment.systemPackages;
    expected = true;
  }
]
