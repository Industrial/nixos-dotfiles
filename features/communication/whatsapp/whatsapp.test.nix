{pkgs, ...}: let
  mockPkgs = {
    stdenv = {
      mkDerivation = attrs: {
        name = attrs.name;
        version = attrs.version;
        src = attrs.src;
        installPhase = attrs.installPhase;
      };
    };
    whatsapp-for-linux = "mock-whatsapp-package";
  };

  whatsappModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = builtins.length whatsappModule.environment.systemPackages;
    expected = 1;
  };

  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "whatsapp-for-linux" mockPkgs;
    expected = true;
  };

  # Test that WhatsApp is in system packages
  testWhatsAppInSystemPackages = {
    expr = builtins.elem mockPkgs.whatsapp-for-linux whatsappModule.environment.systemPackages;
    expected = true;
  };
} 