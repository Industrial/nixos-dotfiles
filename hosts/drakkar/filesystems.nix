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

  fileSystems."/mnt/mimir" = {
    device = "mimir:/data";
    fsType = "nfs4";
    options = ["x-systemd.automount" "nofail" "timeo=14" "x-systemd.idle-timeout=600"];
  };

  systemd.tmpfiles.rules = [
    "d /data/cache 0755 tom users -"
    # Local game root only — do not use mimir as a game station.
    "d /data/Games 0755 tom users -"
  ];
}
