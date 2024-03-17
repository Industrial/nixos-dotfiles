let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "apparmor_test";
    actual = feature.services.dbus.apparmor;
    expected = "enabled";
  }
  {
    name = "apparmor_test";
    actual = feature.security.apparmor.enable;
    expected = true;
  }
  {
    name = "apparmor_test";
    actual = feature.security.apparmor.killUnconfinedConfinables;
    expected = false;
  }
  {
    name = "apparmor_test";
    actual = builtins.elem pkgs.apparmor-pam feature.environment.systemPackages;
    expected = true;
  }
  {
    name = "apparmor_test";
    actual = builtins.elem pkgs.apparmor-utils feature.environment.systemPackages;
    expected = true;
  }
  {
    name = "apparmor_test";
    actual = builtins.elem pkgs.apparmor-parser feature.environment.systemPackages;
    expected = true;
  }
  {
    name = "apparmor_test";
    actual = builtins.elem pkgs.apparmor-profiles feature.environment.systemPackages;
    expected = true;
  }
  {
    name = "apparmor_test";
    actual = builtins.elem pkgs.apparmor-bin-utils feature.environment.systemPackages;
    expected = true;
  }
  {
    name = "apparmor_test";
    actual = builtins.elem pkgs.apparmor-kernel-patches feature.environment.systemPackages;
    expected = true;
  }
  {
    name = "apparmor_test";
    actual = builtins.elem pkgs.libapparmor feature.environment.systemPackages;
    expected = true;
  }
]
