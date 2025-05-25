# features/window-manager/dwm-status/dwm-status.test.nix
# Module evaluation test for the dwm-status feature, similar to c.test.nix
{
  pkgs ?
    import <nixpkgs> {
      system = "x86_64-linux";
      overlays = [];
      config = {};
    }, # Corrected system string
  lib ? pkgs.lib,
  # Mock inputs, similar to how the module would receive them via specialArgs
  inputs ? {
    dwm-status-src = ../../../../rust/tools/dwm-status; # Path to the tool's source dir
  },
}: let
  # Evaluate the dwm-status NixOS module
  eval = lib.evalModules {
    modules = [
      ../../../../features/window-manager/dwm-status/default.nix # The module to test
    ];
    # Pass necessary arguments to the module via specialArgs
    specialArgs = {inherit inputs pkgs lib;};
  };

  # Extracted configuration from the evaluated module
  config = eval.config;

  # Helper to get the system packages list
  systemPackages = config.environment.systemPackages;

  # Helper to get the dwm-status package (assuming it's the first/only one for this module)
  # Note: If the module could add multiple packages, this might need to be more robust.
  # The dwm-status module is simple and adds only itself.
  dwmStatusPackage =
    if builtins.length systemPackages > 0
    then builtins.head systemPackages
    else null; # Should not happen if the module works
in {
  testModuleAddsOnePackageToSystem = {
    expr = builtins.length systemPackages;
    expected = 1;
    message = "The dwm-status module should add exactly one package to environment.systemPackages.";
  };

  testPackagePnameIsDwmStatus = {
    # This test relies on dwmStatusPackage being non-null (covered by the previous test indirectly)
    expr =
      if dwmStatusPackage != null
      then dwmStatusPackage.pname
      else "error: dwmStatusPackage was null";
    expected = "dwm-status";
    message = "The pname of the added package should be 'dwm-status'.";
  };

  testPackageVersionIsSet = {
    # Placeholder version, as it's defined in rust/tools/dwm-status/default.nix
    expr =
      if dwmStatusPackage != null
      then dwmStatusPackage.version
      else "error: dwmStatusPackage was null";
    expected = "0.1.0"; # This should match the version in the package definition
    message = "The version of the dwm-status package should be correctly set.";
  };

  testPackageMetaLicenseIsMIT = {
    expr =
      if dwmStatusPackage != null
      then dwmStatusPackage.meta.license.spdxId
      else "error: dwmStatusPackage was null";
    expected = "MIT";
    message = "The license of the dwm-status package should be MIT.";
  };

  testPackageMetaDescriptionExists = {
    expr =
      if dwmStatusPackage != null
      then (dwmStatusPackage.meta.description != null && dwmStatusPackage.meta.description != "")
      else false;
    expected = true;
    message = "The dwm-status package should have a description.";
  };
}
