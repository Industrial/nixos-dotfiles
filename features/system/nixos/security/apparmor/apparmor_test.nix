let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.services.dbus.apparmor;
    expected = "enabled";
  }
  {
    actual = feature.security.apparmor.enable;
    expected = true;
  }
  {
    actual = feature.security.apparmor.killUnconfinedConfinables;
    expected = false;
  }
  {
    actual = builtins.elem pkgs.apparmor-pam feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.apparmor-utils feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.apparmor-parser feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.apparmor-profiles feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.apparmor-bin-utils feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.apparmor-kernel-patches feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.libapparmor feature.environment.systemPackages;
    expected = true;
  }
]
