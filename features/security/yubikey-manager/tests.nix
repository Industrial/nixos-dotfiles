args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages_yubikey-manager = {
    expr = builtins.elem pkgs.yubikey-manager feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_yubikey-manager-qt = {
    expr = builtins.elem pkgs.yubikey-manager-qt feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_yubikey-personalization-gui = {
    expr = builtins.elem pkgs.yubikey-personalization-gui feature.environment.systemPackages;
    expected = true;
  };
}
