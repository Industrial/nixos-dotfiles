{...}: {
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

  # BFQ on NVMe. The default for NVMe is `none`, which has no notion of priority, so a
  # build's I/O and the desktop's I/O compete as equals. BFQ is the scheduler that honours
  # ionice classes and cgroup io weights (`lowprio` sets both), which lets interactive
  # programs win against a parallel link. Rotational disks keep the kernel's default.
  boot.kernelModules = ["bfq"];
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
  '';
}
