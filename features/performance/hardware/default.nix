{
  config,
  lib,
  pkgs,
  ...
}: {
  # Configure hardware for performance
  hardware = {
    cpu = {
      intel = {
        updateMicrocode = true;
      };
      amd = {
        updateMicrocode = true;
      };
    };

    # hardware.graphics is configured in features/nixos/graphics.
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";
  };
}
