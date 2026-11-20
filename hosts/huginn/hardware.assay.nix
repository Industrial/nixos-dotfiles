# Colocated suite for hosts/huginn/hardware.nix.
#
# Huginn is the StarLite 5 tablet (Intel N200). Two promises here are host-specific and easy to
# lose to a copy from drakkar: hibernation resumes from the swapfile ./disko.nix puts inside
# LUKS, and Aquamarine is pointed at the only GPU this machine has, overriding the drakkar card
# features/window-manager/hyprland pins. Claims read the evaluated NixOS config; the resume
# device is checked against the swap mount disko really generates, and the GPU override against
# a module that sets the hyprland value.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;

  cfg = nixos.eval {
    modules = [./hardware.nix];
    settings.hostname = "huginn";
  };

  withDisko = nixos.eval {
    modules = [nixos.flakeInputs.disko.nixosModules.disko ./disko.nix ./hardware.nix];
    settings.hostname = "huginn";
  };

  # What features/window-manager/hyprland sets for drakkar's discrete card.
  withHyprlandPin = nixos.eval {
    modules = [./hardware.nix {environment.sessionVariables.AQ_DRM_DEVICES = "/dev/dri/card1";}];
    settings.hostname = "huginn";
  };

  initrd = cfg.boot.initrd.availableKernelModules;
in
  assay.suite "huginn-hardware" {
    initrdHasNvme = assay.eq (builtins.elem "nvme" initrd) true;
    initrdHasUsbStorage = assay.eq (builtins.elem "uas" initrd) true;
    initrdHasSdReader = assay.eq (builtins.elem "rtsx_usb_sdmmc" initrd) true;
    loadsKvmIntel = assay.eq (builtins.elem "kvm-intel" cfg.boot.kernelModules) true;

    # The swapfile lives inside LUKS, so resume must name the unlocked mapper device — the one
    # the /swap subvolume is actually mounted from — not a partition.
    resumesFromCryptroot = assay.eq cfg.boot.resumeDevice "/dev/mapper/cryptroot";
    resumeDeviceHoldsSwap = assay.eq withDisko.boot.resumeDevice withDisko.fileSystems."/swap".device;

    # card1 does not exist on a single-GPU machine; Aquamarine would find no device at login.
    aquamarineUsesOnlyGpu = assay.eq withHyprlandPin.environment.sessionVariables.AQ_DRM_DEVICES "/dev/dri/card0";

    enablesAllFirmware = assay.eq cfg.hardware.enableAllFirmware true;
    bluetoothOnAtBoot = assay.eq {inherit (cfg.hardware.bluetooth) enable powerOnBoot;} {
      enable = true;
      powerOnBoot = true;
    };
    enablesBlueman = assay.eq cfg.services.blueman.enable true;
    enablesPowerManagement = assay.eq cfg.powerManagement.enable true;
  }
