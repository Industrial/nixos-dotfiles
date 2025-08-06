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
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Configure audio for performance
    pulseaudio = {
      enable = true;
      package = pkgs.pulseaudioFull;
    };
  };

  # Configure power management for performance
  services = {
    powerManagement = {
      enable = true;
      cpuFreqGovernor = "performance";
      powertop.enable = true;
    };
  };

  # Configure system packages for performance
  environment.systemPackages = with pkgs; [
    # Performance monitoring tools
    htop
    iotop
    iostat
    sysstat
    perf-tools
    powertop

    # Performance optimization tools
    cpupower
    turbostat
    numactl

    # Network performance tools
    iperf3
    netperf
    ethtool

    # Storage performance tools
    fio
    iozone3
    bonnie
  ];
}
