{
  settings,
  pkgs,
  ...
}: {
  # Disable kernel module loading once the system is fully initialised.  Module
  # loading is disabled until the next reboot. Problems caused by delayed module
  # loading can be fixed by adding the module(s) in question to
  # {option}`boot.kernelModules`.
  security.lockKernelModules = true;

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = true;
  security.sudo.execWheelOnly = true;
}
