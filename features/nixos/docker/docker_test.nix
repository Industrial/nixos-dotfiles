let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "docker_test";
    actual = feature.virtualisation.docker.enable;
    expected = true;
  }
]
