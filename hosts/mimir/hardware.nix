{...}: {
  # Mimir is an AOOSTAR WTR PRO (Ryzen 7 5825U): four bays on two 2-port AHCI controllers
  # (0000:05:00.0 / 05:00.1). The kernel's default mobile LPM policy on this chipset is
  # med_power_with_dipm, under which bay 3 (ata3) throws `interface fatal error` /
  # `SError: { UnrecovData 10B8B BadCRC }` and hard-resets its link — seen on the first boot
  # after the 2026-11-20 reinstall, with a btrfs read error on that member. AOOSTAR's own fix
  # is SATA link power management at max performance; 1 = max_performance. Costs a few watts
  # of idle power and keeps the RAID5 members off the reset path.
  boot.kernelParams = ["ahci.mobile_lpm_policy=1"];

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

  # Mimir is the always-on file server (NFS, Prometheus/Grafana, the RustDesk relay), so it
  # must never sleep. GDM's greeter suspends an idle machine after ~20 minutes on its own —
  # on 2026-11-20 that took mimir off the tailnet whenever nobody was logged in. Turn the
  # greeter's auto-suspend off, and mask the sleep targets so nothing else (logind idle
  # action, a GNOME session's power settings, a stray `systemctl suspend`) can do it either.
  services.displayManager.gdm.autoSuspend = false;
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
