# sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount ./hosts/huginn/disko.nix --yes-wipe-all-disks
#
# Huginn is the StarLite 5 tablet: one soldered-in M.2 NVMe, no second disk. The layout is the
# fleet standard (ESP + LUKS + btrfs subvolumes) with three tablet-specific departures:
#
#   1. compress=zstd on the data subvolumes. The tablet has the smallest disk in the fleet and
#      the only one that is also the scratch disk for development, so transparent compression
#      buys both capacity and fewer NVMe writes.
#   2. noatime everywhere. Nothing here reads atimes, and every atime update is a write.
#   3. An @swap subvolume holding a swapfile large enough to hibernate. A tablet gets closed and
#      carried far more often than it gets shut down, and suspend-to-RAM alone drains the
#      battery. See boot.resumeDevice in ./hardware.nix for the resume half of this.
#
# The btrfs filesystem deliberately has no top-level `mountpoint`. Setting one makes disko mount
# subvolid 5 at the mount root during install — it wins the attrset collision against the @root
# subvolume mount — so nixos-install writes `/` into the bare volume while the installed system
# boots with subvol=@root. Mounting only via subvolumes keeps install-time and boot-time `/`
# the same subvolume.
{...}: let
  # Data subvolumes: compressed, no atime writes.
  dataOptions = ["compress=zstd" "noatime"];
in {
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
                    subvolumes = {
                      "@root" = {
                        mountpoint = "/";
                        mountOptions = dataOptions;
                      };
                      "@nix" = {
                        mountpoint = "/nix";
                        mountOptions = dataOptions;
                      };
                      "@home" = {
                        mountpoint = "/home";
                        mountOptions = dataOptions;
                      };
                      "@var" = {
                        mountpoint = "/var";
                        mountOptions = dataOptions;
                      };

                      # Hibernation swap, on its own subvolume so it can be mounted without
                      # compression. `btrfs filesystem mkswapfile` marks the file NODATACOW,
                      # which already exempts it from compression and checksums; keeping the
                      # subvolume itself uncompressed means nothing about this swapfile depends
                      # on that per-file flag surviving a future edit.
                      #
                      # 20G covers the 16G LPDDR5 the StarLite 5 ships with, plus headroom so a
                      # near-full memory image still fits. Shrink it only alongside RAM.
                      "@swap" = {
                        mountpoint = "/swap";
                        mountOptions = ["noatime"];
                        swap.swapfile.size = "20G";
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
