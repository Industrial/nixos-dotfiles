{
  config,
  lib,
  pkgs,
  ...
}: {
  # YubiKey support
  environment = {
    systemPackages = with pkgs; [
      # YubiKey tools
      yubikey-manager
      yubikey-personalization
      yubico-piv-tool
      yubico-pam

      # PIV and PIV Manager
      yubico-piv-tool
      yubico-pam

      # FIDO2 support
      libfido2
      yubico-pam
    ];
  };

  # PAM configuration for YubiKey
  security = {
    pam = {
      services = {
        # Configure login to use YubiKey
        login = {
          # YubiKey PAM module will be available via yubico-pam package
        };

        # Configure sudo to use YubiKey
        sudo = {
          # YubiKey PAM module will be available via yubico-pam package
        };

        # Configure su to use YubiKey
        su = {
          # YubiKey PAM module will be available via yubico-pam package
        };
      };
    };
  };

  # Services
  services = {
    # PC/SC daemon for smart card support
    pcscd = {
      enable = true;
    };

    # udev rules for YubiKey
    udev = {
      extraRules = ''
        # YubiKey
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0010", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0110", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0111", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0112", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0113", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0114", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0115", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0116", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0120", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0121", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0122", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0123", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0124", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0125", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0126", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0127", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0128", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0129", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0130", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0131", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0132", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0133", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0134", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0135", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0136", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0137", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0138", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0139", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0140", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0141", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0142", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0143", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0144", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0145", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0146", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0147", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0148", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0149", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0150", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0151", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0152", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0153", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0154", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0155", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0156", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0157", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0158", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0159", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0160", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0161", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0162", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0163", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0164", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0165", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0166", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0167", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0168", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0169", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0170", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0171", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0172", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0173", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0174", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0175", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0176", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0177", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0178", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0179", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0180", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0181", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0182", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0183", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0184", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0185", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0186", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0187", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0188", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0189", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0190", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0191", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0192", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0193", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0194", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0195", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0196", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0197", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0198", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0199", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1050", ATTR{idProduct}=="0200", MODE="0664", GROUP="plugdev"
      '';
    };
  };
}
