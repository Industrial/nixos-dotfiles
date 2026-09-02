{...}: {
  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "nvme" "usbhid" "uas" "sd_mod" "rtsx_usb_sdmmc"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
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

  powerManagement = {
    enable = true;
  };
}
