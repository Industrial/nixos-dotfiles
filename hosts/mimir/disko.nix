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
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                content = {
                  type = "btrfs";
                  mountpoint = "/";
                  subvolumes = {
                    "@root" = { mountpoint = "/"; };
                    "@nix" = { mountpoint = "/nix"; };
                    "@persist" = { mountpoint = "/persist"; };
                  };
                };
              };
            };
          };
        };
      };

      hdds = {
        device = [ "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" ];
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptdata";
                content = {
                  type = "btrfs";
                  mountpoint = "/data";
                  options = [ "nofail" "compress=zstd" ];
                  raid = {
                    level = 5;
                    devices = [
                      "/dev/mapper/cryptdata-a"
                      "/dev/mapper/cryptdata-b"
                      "/dev/mapper/cryptdata-c"
                      "/dev/mapper/cryptdata-d"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };

    luks = {
      cryptroot = {
        device = "/dev/nvme0n1p2";
        allowDiscards = true;
        keyFile = null;
      };

      cryptdata-a = { device = "/dev/sda1"; };
      cryptdata-b = { device = "/dev/sdb1"; };
      cryptdata-c = { device = "/dev/sdc1"; };
      cryptdata-d = { device = "/dev/sdd1"; };
    };

    swapDevices = [
      {
        device = "/dev/mapper/cryptroot";
        size = "8G";
        priority = 1;
        resumeDevice = true;
      }
    ];
  };
} 
