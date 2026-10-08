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

  systemd.tmpfiles.rules = [
    "d /data/cache 0755 tom users -"
    # Local game root only — do not use mimir as a game station.
    "d /data/Games 0755 tom users -"
  ];
}
