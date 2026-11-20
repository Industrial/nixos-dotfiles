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
