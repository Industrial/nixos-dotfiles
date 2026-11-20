# Colocated suite for hosts/drakkar/hardware.nix.
#
# Drakkar is wired-only by policy, and this module enforces it at three layers: the Qualcomm
# WiFi-7 driver and the 802.11 stack are blacklisted so the NIC never binds (commit ccc7592e),
# NetworkManager ignores any wl* interface that appears anyway, and a oneshot rfkill-blocks the
# radio at boot. Each layer is claimed separately so losing one fails on its own.
#
# Claims read the evaluated NixOS config. The "forced" claims evaluate against a module that
# switches WiFi back on, the way a shared feature would, and check that this host still wins.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [./hardware.nix];
    settings.hostname = "drakkar";
  };
  contested = nixos.eval {
    modules = [./hardware.nix {networking.wireless.enable = true;}];
    settings.hostname = "drakkar";
  };

  blacklisted = m: builtins.elem m cfg.boot.blacklistedKernelModules;
  rfkill = cfg.systemd.services.rfkill-block-wlan;
in
  assay.suite "drakkar-hardware" {
    # The device driver itself: with it blacklisted the PCI NIC never binds.
    blacklistsAth12kPci = assay.eq (blacklisted "ath12k_pci") true;
    blacklistsAth12kCore = assay.eq (blacklisted "ath12k") true;
    # Defence in depth: no 802.11 stack for any other driver to bring up a wl* interface.
    blacklists80211Stack = assay.eq (blacklisted "cfg80211" && blacklisted "mac80211") true;

    wirelessForcedOff = assay.eq contested.networking.wireless.enable false;
    networkManagerIgnoresWlan = assay.eq (builtins.elem "interface-name:wl*" cfg.networking.networkmanager.unmanaged) true;

    rfkillRunsAtBoot = assay.eq (builtins.elem "multi-user.target" rfkill.wantedBy) true;
    rfkillWaitsForUdev = assay.eq (builtins.elem "systemd-udevd.service" rfkill.after) true;
    rfkillIsOneshot = assay.subset rfkill.serviceConfig {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    rfkillBlocksWifi = assay.eq (lib.hasSuffix "/bin/rfkill block wifi" rfkill.serviceConfig.ExecStart) true;

    enablesAllFirmware = assay.eq cfg.hardware.enableAllFirmware true;
    bluetoothOnAtBoot = assay.eq {inherit (cfg.hardware.bluetooth) enable powerOnBoot;} {
      enable = true;
      powerOnBoot = true;
    };
    enablesBlueman = assay.eq cfg.services.blueman.enable true;
    enablesPowerManagement = assay.eq cfg.powerManagement.enable true;
  }
