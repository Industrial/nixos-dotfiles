{
  settings,
  pkgs,
  ...
}: {
  services.dbus.apparmor = "enabled";
  security.apparmor.enable = true;
  # security.apparmor.policies = {};
  # security.apparmor.packages = [];
  # security.apparmor.includes = {};

  # Whether to enable killing of processes which have an AppArmor profile
  # enabled (in security.apparmor.policies) but are not confined (because
  # AppArmor can only confine new processes).
  security.apparmor.killUnconfinedConfinables = false;

  environment.systemPackages = with pkgs; [
    apparmor-pam
    apparmor-utils
    apparmor-parser
    apparmor-profiles
    apparmor-bin-utils
    apparmor-kernel-patches
    libapparmor
  ];

  # Disable kernel module loading once the system is fully initialised.  Module
  # loading is disabled until the next reboot. Problems caused by delayed module
  # loading can be fixed by adding the module(s) in question to
  # {option}`boot.kernelModules`.
  security.lockKernelModules = true;

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = true;
  security.sudo.execWheelOnly = true;
}
