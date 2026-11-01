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
