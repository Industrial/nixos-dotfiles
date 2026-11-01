{lib, ...}: {
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "nvme" "usbhid" "uas" "sd_mod" "rtsx_usb_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];

    # Resume-from-hibernation half of the @swap subvolume in ./disko.nix. The swapfile lives
    # inside the LUKS container, so the device named here is the unlocked mapper device, not a
    # partition; initrd unlocks it before systemd-hibernate-resume runs.
    #
    # The kernel's own resume path also wants `resume_offset=` — the physical offset of the
    # swapfile within the filesystem — which cannot be known until the file exists on the real
    # disk. systemd records the offset in the `HibernateLocation` EFI variable when it
    # hibernates and systemd-hibernate-resume reads it back, so resume works without the
    # parameter. If it ever does not, get the number on the device with
    #
    #   btrfs inspect-internal map-swapfile -r /swap/swapfile
    #
    # and add `boot.kernelParams = ["resume_offset=<n>"];` here. A missing or stale offset only
    # costs a failed resume attempt and a normal boot; it cannot corrupt the filesystem.
    resumeDevice = "/dev/mapper/cryptroot";
  };

  hardware = {
    enableAllFirmware = true;

    # Enable Bluetooth hardware support
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  services = {
    blueman = {
      enable = true;
    };
  };

  environment = {
    sessionVariables = {
      # features/window-manager/hyprland pins Aquamarine to /dev/dri/card1, which is drakkar's
      # discrete RX 6950 XT. Huginn has one GPU — the N200's integrated Intel — so card1 does
      # not exist here and Aquamarine finds no usable device at session start. Point it at the
      # only card present.
      AQ_DRM_DEVICES = lib.mkForce "/dev/dri/card0";
    };
  };

  powerManagement = {
    enable = true;
  };
}
