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

    # Configure GPU for performance
    graphics = {
      enable = true;
      # driSupport = true;
      # driSupport32Bit = true;
    };
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";
  };
}
