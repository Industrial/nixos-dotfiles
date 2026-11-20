# sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount ./hosts/drakkar/disko.nix --yes-wipe-all-disks
{...}: {
  disko = {
    devices = {
      disk = {
        ssd = {
          device = "/dev/nvme0n1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  extraArgs = ["-F" "32"];
                  mountOptions = [
                    "umask=0077"
                    "dmask=0077"
                    "fmask=0077"
                  ];
                };
              };
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "cryptroot";
                  keyFile = null;
                  # dm-crypt encrypts in the submitting thread instead of handing every I/O
                  # to its own kcryptd workqueues. On NVMe the queueing is what costs: it
                  # adds latency to every read and write, and under a heavy write burst it
                  # is where fsync() callers end up waiting. Lands in
                  # boot.initrd.luks.devices.cryptroot.bypassWorkqueues; applies on the next
                  # unlock (reboot), or live with `cryptsetup refresh --perf-no_read_workqueue
                  # --perf-no_write_workqueue cryptroot`.
                  settings.bypassWorkqueues = true;
                  content = {
                    type = "btrfs";
                    # No top-level mountpoint. With one set, disko mounts subvolid 5 at the
                    # mount root during install — it wins the attrset collision against the
                    # @root subvolume mount — so nixos-install writes `/` into the bare volume
                    # while the installed system boots with subvol=@root. Harmless on a running
                    # host (it only drops a duplicate "defaults" from the mount options), but
                    # it silently misplaces `/` on the next reinstall.
                    #
                    # The /data volume below keeps its mountpoint: it declares no subvolumes,
                    # so there is no collision to lose.
                    subvolumes = {
                      "@root" = {mountpoint = "/";};
                      "@nix" = {mountpoint = "/nix";};
                      "@home" = {mountpoint = "/home";};
                      "@var" = {mountpoint = "/var";};
                    };
                  };
                };
              };
            };
          };
        };

        hdd = {
          device = "/dev/sda";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              data = {
                size = "100%";
                content = {
                  type = "btrfs";
                  mountpoint = "/data";
                };
              };
            };
          };
        };
      };
    };
  };
}
