{pkgs, ...}: let
  mockPkgs = {
    ollama = "mock-ollama-package";
    ollama-cuda = "mock-ollama-cuda-package";
  };

  module = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.all (pkg: builtins.hasAttr pkg pkgs) ["ollama" "ollama-cuda"];
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = module.environment.systemPackages;
    expected = [
      "mock-ollama-package"
      "mock-ollama-cuda-package"
    ];
  };

  # Test ollama service configuration
  testOllamaServiceConfig = {
    expr = {
      enable = module.services.ollama.enable;
      host = module.services.ollama.host;
      port = module.services.ollama.port;
      loadModels = module.services.ollama.loadModels;
    };
    expected = {
      enable = true;
      host = "[::]";
      port = 11434;
      loadModels = ["codegemma"];
    };
  };

  # Test nextjs-ollama-llm-ui service configuration
  testNextjsOllamaLlmUiConfig = {
    expr = {
      enable = module.services.nextjs-ollama-llm-ui.enable;
      port = module.services.nextjs-ollama-llm-ui.port;
    };
    expected = {
      enable = true;
      port = 5001;
    };
  };
}
