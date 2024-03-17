let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "nginx_test";
    actual = feature.services.nginx.enable;
    expected = true;
  }
  {
    name = "nginx_test";
    actual = feature.services.nginx.recommendedGzipSettings;
    expected = true;
  }
]
