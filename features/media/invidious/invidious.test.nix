{pkgs, ...}: let
  module = import ./default.nix {inherit pkgs;};
in {
  # Test that the service is enabled
  testServiceEnabled = {
    expr = module.services.invidious.enable;
    expected = true;
  };

  # Test service port configuration
  testServicePort = {
    expr = module.services.invidious.port;
    expected = 4000;
  };
}
