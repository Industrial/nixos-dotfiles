# Colocated suite for hosts/muninn/hardware.nix.
#
# Muninn is an Intel laptop-class machine: the initrd needs the NVMe and USB storage drivers to
# reach its root disk, KVM is the Intel flavour, and it shares the fleet's firmware, Bluetooth
# and power-management stance. Claims read the evaluated NixOS config.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {
    modules = [./hardware.nix];
    settings.hostname = "muninn";
  };
  initrd = cfg.boot.initrd.availableKernelModules;
in
  assay.suite "muninn-hardware" {
    initrdHasNvme = assay.eq (builtins.elem "nvme" initrd) true;
    initrdHasUsbStorage = assay.eq (builtins.elem "uas" initrd) true;
    initrdHasSdReader = assay.eq (builtins.elem "rtsx_usb_sdmmc" initrd) true;
    # kvm-amd here would leave virtualisation without acceleration.
    loadsKvmIntel = assay.eq (builtins.elem "kvm-intel" cfg.boot.kernelModules) true;

    enablesAllFirmware = assay.eq cfg.hardware.enableAllFirmware true;
    bluetoothOnAtBoot = assay.eq {inherit (cfg.hardware.bluetooth) enable powerOnBoot;} {
      enable = true;
      powerOnBoot = true;
    };
    enablesBlueman = assay.eq cfg.services.blueman.enable true;
    enablesPowerManagement = assay.eq cfg.powerManagement.enable true;
  }
