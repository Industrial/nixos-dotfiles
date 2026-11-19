# Host hardware — drakkar (Gigabyte X870E AORUS MASTER).
{
  lib,
  pkgs,
  ...
}: {
  hardware = {
    enableAllFirmware = true;

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

  networking = {
    wireless.enable = lib.mkForce false;
    networkmanager = {
      unmanaged = ["interface-name:wl*"];
    };
  };

  boot.blacklistedKernelModules = [
    # drakkar is wired-only by policy (features/nixos/networking + the
    # rfkill-block service below). Blacklist the Qualcomm WiFi-7 device
    # driver directly so the PCI NIC never binds and never brings up a
    # wl* interface; keep the 802.11 core blacklisted as defence in depth.
    "ath12k_pci"
    "ath12k"
    "cfg80211"
    "mac80211"
  ];

  systemd.services.rfkill-block-wlan = {
    description = "Block Wi-Fi radio";
    wantedBy = ["multi-user.target"];
    after = ["systemd-udevd.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe' pkgs.util-linux "rfkill"} block wifi";
    };
  };

  powerManagement = {
    enable = true;
  };
}
