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
      device = "LABEL=data";
      fsType = "btrfs";
      options = ["compress=zstd" "defaults"];
    };
  };

  systemd.tmpfiles.rules = [
    "d /data/archive 0755 tom users -"
    "d /data/docker 0755 tom users -"
    "d /data/scratch 0777 tom users -"
    "d /data/cache 0755 tom users -"
  ];
}
