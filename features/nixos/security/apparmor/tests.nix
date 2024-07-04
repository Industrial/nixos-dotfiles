args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_services_dbus_apparmor = {
    expr = feature.services.dbus.apparmor;
    expected = "enabled";
  };
  test_security_apparmor_enable = {
    expr = feature.security.apparmor.enable;
    expected = true;
  };
  test_security_apparmor_killUnconfinedConfinables = {
    expr = feature.security.apparmor.killUnconfinedConfinables;
    expected = false;
  };
  test_environment_systemPackages_apparmor-pam = {
    expr = builtins.elem pkgs.apparmor-pam feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_apparmor-utils = {
    expr = builtins.elem pkgs.apparmor-utils feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_apparmor-parser = {
    expr = builtins.elem pkgs.apparmor-parser feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_apparmor-profiles = {
    expr = builtins.elem pkgs.apparmor-profiles feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_apparmor-bin-utils = {
    expr = builtins.elem pkgs.apparmor-bin-utils feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_apparmor-kernel-patches = {
    expr = builtins.elem pkgs.apparmor-kernel-patches feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_libapparmor = {
    expr = builtins.elem pkgs.libapparmor feature.environment.systemPackages;
    expected = true;
  };
}
