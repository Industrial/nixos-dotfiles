let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.services.nginx.enable;
    expected = true;
  }
  {
    actual = feature.services.nginx.recommendedGzipSettings;
    expected = true;
  }
]
