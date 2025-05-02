# sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount ./hosts/mimir/disko.nix --yes-wipe-all-disks
{...}: {
  disko.devices = {
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
                extraArgs = [ "-F" "32" ];
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
                  mountpoint = "/";
                  subvolumes = {
                    "@root" = { mountpoint = "/"; };
                    "@nix" = { mountpoint = "/nix"; };
                  };
                };
              };
            };
          };
        };
      };

      hdd-a = {
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "btrfs";
              };
            };
          };
        };
      };
      hdd-b = {
        device = "/dev/sdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "btrfs";
              };
            };
          };
        };
      };
      hdd-c = {
        device = "/dev/sdc";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "btrfs";
              };
            };
          };
        };
      };
      hdd-d = {
        device = "/dev/sdd";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "btrfs";
              };
            };
          };
        };
      };
    };
  };

  #disko.postMountCommands = ''
  #  mkfs.btrfs -L data -m raid5 -d raid5 \
  #    /dev/sda1 /dev/sdb1 /dev/sdc1 /dev/sdd1
  #  mkdir -p /mnt/data
  #  mount -o compress=zstd LABEL=data /mnt/data
  #'';
}

