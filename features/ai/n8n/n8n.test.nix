{pkgs, ...}: let
  mockPkgs = {
    n8n = "mock-n8n-package";
    nodejs_latest = "mock-nodejs-package";
    supabase-cli = "mock-supabase-package";
  };

  n8nModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.all (pkg: builtins.hasAttr pkg pkgs) ["n8n" "nodejs_latest" "supabase-cli"];
    expected = true;
  };

  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = n8nModule.environment.systemPackages;
    expected = [
      "mock-n8n-package"
      "mock-nodejs-package"
      "mock-supabase-package"
    ];
  };

  # Test that n8n service is enabled
  testN8nServiceEnabled = {
    expr = n8nModule.services.n8n.enable;
    expected = true;
  };
}
