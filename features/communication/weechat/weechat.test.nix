{...}: let
  mockPkgs = {
    stdenv = {
      mkDerivation = attrs: {
        name = attrs.name;
        version = attrs.version;
        src = attrs.src;
        installPhase = attrs.installPhase;
      };
    };
    weechat = "mock-weechat-package";
  };

  weechatModule = import ./default.nix {pkgs = mockPkgs;};
in {
  # Test that the module evaluates without errors
  testModuleEvaluates = {
    expr = builtins.length weechatModule.environment.systemPackages;
    expected = 1;
  };

  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "weechat" mockPkgs;
    expected = true;
  };

  # Test that WeeChat is in system packages
  testWeeChatInSystemPackages = {
    expr = builtins.elem mockPkgs.weechat weechatModule.environment.systemPackages;
    expected = true;
  };
}
