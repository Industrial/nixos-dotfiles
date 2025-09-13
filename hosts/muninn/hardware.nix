{...}: {
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
