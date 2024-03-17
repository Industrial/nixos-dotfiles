let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "ollama_test";
    actual = feature.services.ollama.enable;
    expected = true;
  }
]
