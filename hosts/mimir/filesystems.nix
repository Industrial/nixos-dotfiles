{
  boot = {
    initrd = {
      availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
      kernelModules = [];
    };

    kernelModules = ["kvm-amd"];
    supportedFilesystems = ["btrfs"];
  };

  services = {
    btrfs = {
      autoScrub = {
        enable = true;
        fileSystems = ["/data"];
        interval = "monthly";
      };
    };
  };

  fileSystems = {
    "/data" = {
      device = "LABEL=data";
      fsType = "btrfs";
      # nofail: without it, a /data that cannot be mounted fails local-fs.target and drops this
      # machine to an emergency shell. Mimir is headless, so that is a shell nobody can reach —
      # a single failed disk would turn a degraded file server into an unreachable one. With
      # nofail the host boots, SSH comes up, and the array can be repaired remotely.
      #
      # RAID5 will not mount with a member missing unless you add `-o degraded`, so this is not
      # a hypothetical: it is the expected behaviour the first time a disk dies.
      #
      # The cost of nofail is that /data silently becomes an empty directory on the root
      # filesystem, which is why nfs-server is gated on the real mount below. Nothing else
      # active writes here: docker is disabled on this host and every features/media service is
      # commented out of ./configuration.nix. The four tmpfiles directories above would be
      # created on the root filesystem, which is harmless — they are shadowed once the array
      # mounts — but it does mean `ls /data` succeeding is not proof the array is there. Use
      # `findmnt /data`.
      options = ["compress=zstd" "defaults" "nofail"];
    };
  };

  systemd = {
    services = {
      # Never export /data unless /data is really the array. With nofail above, an unmounted
      # /data is an empty directory on the root filesystem, and NFS would serve it happily —
      # clients would mount an empty /mnt/mimir and, being rw exports, could write into it.
      # RequiresMountsFor pulls in data.mount and fails this unit if the mount failed, so the
      # host still boots and stays reachable while NFS correctly refuses to serve nothing.
      nfs-server = {
        unitConfig = {
          RequiresMountsFor = "/data";
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /data/archive 0755 tom users -"
    "d /data/docker 0755 tom users -"
    "d /data/scratch 0777 tom users -"
    "d /data/cache 0755 tom users -"
  ];
}
