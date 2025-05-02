{
  boot.initrd = {
    availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
    kernelModules = [];
  };

  boot.kernelModules = ["kvm-amd"];

  boot.supportedFilesystems = ["btrfs"];

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/data" ];
    interval = "monthly";
  };
}

