{
  boot = {
    initrd = {
      availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
      kernelModules = [];
    };

    kernelModules = ["kvm-amd"];
    supportedFilesystems = ["btrfs"];
  };

  services = {
    btrfs = {
      autoScrub = {
        enable = true;
        fileSystems = ["/data"];
        interval = "monthly";
      };
    };
  };

  fileSystems = {
    "/data" = {
      device = "/dev/sda1";
      fsType = "btrfs";
      options = ["compress=zstd" "defaults"];
    };
  };
} 