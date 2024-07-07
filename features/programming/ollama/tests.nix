args @ {...}: let
  feature = import ./default.nix args;
in {
  test_services_ollama_enable = {
    expr = feature.services.ollama.enable;
    expected = true;
  };
}
