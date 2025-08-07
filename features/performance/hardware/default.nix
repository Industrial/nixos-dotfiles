{
  config,
  lib,
  pkgs,
  ...
}: {
  # Performance hardware configuration

  # Configure hardware for performance
  hardware = {
    # Enable CPU performance governor
    cpu.intel.updateMicrocode = true;
    cpu.amd.updateMicrocode = true;

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
    powertop.enable = true;
  };

  # TODO: Move these into individual features if we really need them.
  # # Configure system packages for performance
  # environment.systemPackages = with pkgs; [
  #   # Performance monitoring tools
  #   htop
  #   iotop
  #   sysstat
  #   perf-tools
  #   powertop
  #   # Performance optimization tools
  #   turbostat
  #   numactl
  #   # Network performance tools
  #   iperf3
  #   netperf
  #   ethtool
  #   # Storage performance tools
  #   fio
  #   iozone3
  #   bonnie
  # ];
}
