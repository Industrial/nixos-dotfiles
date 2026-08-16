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
