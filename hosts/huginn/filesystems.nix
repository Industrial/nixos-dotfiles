{
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "nvme" "usbhid" "uas" "sd_mod" "rtsx_usb_sdmmc"];
      kernelModules = [];

      luks = {
        devices = {
          "luks-43521c75-c1cb-4b8a-875e-209640141530" = {
            device = "/dev/disk/by-uuid/43521c75-c1cb-4b8a-875e-209640141530";
          };
        };
      };
    };

    kernelModules = ["kvm-intel"];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/f3adb911-b6a6-47ac-9490-ea200135ad8b";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/3BE3-A3FE";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };
  };
}
