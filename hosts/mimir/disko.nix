# Non-destructive (keeps an existing /data array):
#   nix run .#nixosConfigurations.mimir.config.system.build.formatMount
# Destructive (wipes all five disks, /data included):
#   nix run .#nixosConfigurations.mimir.config.system.build.destroyFormatMount -- --yes-wipe-all-disks
#
# `install-nixos mimir` uses the first form. See hosts/mimir/INSTALL.md.
#
# Mimir is the file server: one NVMe for the system, four HDDs carrying a single btrfs RAID5
# volume labelled `data` (~55 TB usable, see ./DATA.md).
#
# The RAID5 volume used to live only in a comment here, which meant disko formatted the four
# HDDs as four separate single-disk filesystems and the array had to be built by hand
# afterwards. It is declared properly now, and declared so that it is created only when absent:
# disko's btrfs type guards mkfs behind `blkid <device> | grep -q '^TYPE='`, so an array that
# already exists is left alone. The partition table is equally conservative — `sgdisk --clear`
# runs only when the disk carries no signature at all, and partition creation falls back to
# relabelling when the partition is already there.
{...}: let
  # The three RAID5 members that are not the one carrying the mkfs call below.
  raid5Members = [
    "/dev/disk/by-partlabel/disk-hdd-a-data"
    "/dev/disk/by-partlabel/disk-hdd-b-data"
    "/dev/disk/by-partlabel/disk-hdd-c-data"
  ];

  # A RAID5 member whose partition disko creates but must not format: the volume spanning all
  # four is created once, on hdd-d.
  raid5Member = device: {
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        data = {
          size = "100%";
          # No content. disko creates and labels the partition, then leaves it untouched —
          # `lib.filter (p: p.content != null)` skips it in both the create and mount phases.
          # It gets its filesystem from the mkfs.btrfs on hdd-d.
          content = null;
        };
      };
    };
  };
in {
  disko = {
    devices = {
      disk = {
        # IMPORTANT: hdd-a/b/c carry no content; the array is created on hdd-d, which must sort
        # last. disko emits disks in attribute-name order and has no dependency tracking for
        # multi-device btrfs (extraArgs is an opaque string list), so the mkfs must come after
        # every member partition exists. If you rename these disks, keep the one holding
        # extraArgs alphabetically last, or mkfs.btrfs fails on a missing by-partlabel path.
        hdd-a = raid5Member "/dev/sda";
        hdd-b = raid5Member "/dev/sdb";
        hdd-c = raid5Member "/dev/sdc";

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
                  # disko runs `mkfs.btrfs <device> <extraArgs>`, so the other three members
                  # ride along as positional arguments. The filesystem label is what
                  # ./filesystems.nix mounts /data by, which keeps the mount independent of
                  # which member device the kernel happens to enumerate first.
                  extraArgs =
                    ["-L" "data" "-m" "raid5" "-d" "raid5"] ++ raid5Members;
                  # Deliberately no mountpoint: ./filesystems.nix owns the /data mount, by
                  # label. Declaring it here too would collide on fileSystems."/data".device.
                  # Nothing in nixos-install needs /data, so it stays unmounted during install.
                };
              };
            };
          };
        };

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
                    # while the installed system boots with subvol=@root. Mimir feels this
                    # harder than the other hosts because it declares no @home or @var, so
                    # more of the tree lives in @root.
                    subvolumes = {
                      "@root" = {mountpoint = "/";};
                      "@nix" = {mountpoint = "/nix";};
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
