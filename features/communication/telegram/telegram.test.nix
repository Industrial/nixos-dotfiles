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
    telegram-desktop = "mock-telegram-package";
  };

  telegramModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = builtins.length telegramModule.environment.systemPackages;
    expected = 1;
  };

  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "telegram-desktop" mockPkgs;
    expected = true;
  };

  # Test that Telegram is in system packages
  testTelegramInSystemPackages = {
    expr = builtins.elem mockPkgs.telegram-desktop telegramModule.environment.systemPackages;
    expected = true;
  };
} 