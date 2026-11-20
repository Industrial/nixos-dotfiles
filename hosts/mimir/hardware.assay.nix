# Colocated suite for hosts/mimir/hardware.nix.
#
# Mimir's hardware module is the fleet's common hardware stance plus one host-specific fix
# (SATA link power at max performance, for the WTR PRO's bay 3; storage drivers live in
# ./filesystems.nix): full redistributable and unfree firmware,
# Bluetooth powered at boot with blueman, and power management. Claims read the evaluated NixOS
# config, so they also hold if the module is refactored into a shared profile.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {
    modules = [./hardware.nix];
    settings.hostname = "mimir";
  };
in
  assay.suite "mimir-hardware" {
    # Without it the NIC, GPU and Bluetooth blobs are missing and devices come up dead.
    enablesAllFirmware = assay.eq cfg.hardware.enableAllFirmware true;
    bluetoothOnAtBoot = assay.eq {inherit (cfg.hardware.bluetooth) enable powerOnBoot;} {
      enable = true;
      powerOnBoot = true;
    };
    enablesBlueman = assay.eq cfg.services.blueman.enable true;
    enablesPowerManagement = assay.eq cfg.powerManagement.enable true;
    # Driver blacklisting is drakkar's wired-only policy; copied here it would silently take
    # mimir's radios down with it.
    blacklistsNoModules = assay.eq cfg.boot.blacklistedKernelModules [];
    # The always-on file server must never sleep: GDM's greeter auto-suspend took it off the
    # tailnet whenever nobody was logged in.
    greeterNeverSuspends = assay.eq cfg.services.displayManager.gdm.autoSuspend false;
    sleepTargetsDisabled =
      assay.eq (map (t: cfg.systemd.targets.${t}.enable) ["sleep" "suspend" "hibernate" "hybrid-sleep"])
      [false false false false];
    # Bay 3 hard-resets its link with BadCRC under the default med_power_with_dipm policy;
    # max_performance (1) is AOOSTAR's fix. Losing it puts a RAID5 member back on the reset path.
    sataLpmMaxPerformance = assay.eq (builtins.elem "ahci.mobile_lpm_policy=1" cfg.boot.kernelParams) true;
  }
