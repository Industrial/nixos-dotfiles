# Colocated suite for hosts/mimir/filesystems.nix.
#
# Mimir is a headless file server, so this module's job is to keep a degraded /data array from
# turning into an unreachable host, and to keep NFS from serving an empty directory when the
# array is missing. Claims read the evaluated NixOS config; the /data label is also checked
# against the label ./disko.nix passes to mkfs.btrfs, since the two files only agree by
# convention and a mismatch means /data never mounts.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [./filesystems.nix];
    settings.hostname = "mimir";
  };

  withDisko = nixos.eval {
    modules = [nixos.flakeInputs.disko.nixosModules.disko ./disko.nix ./filesystems.nix];
    settings.hostname = "mimir";
  };
  mkfsArgs = withDisko.disko.devices.disk.hdd-d.content.partitions.data.content.extraArgs;
  mkfsLabel = builtins.elemAt mkfsArgs (lib.lists.findFirstIndex (a: a == "-L") null mkfsArgs + 1);

  data = cfg.fileSystems."/data";
  initrd = cfg.boot.initrd.availableKernelModules;
in
  assay.suite "mimir-filesystems" {
    # Mounted by label, so it does not depend on which member the kernel enumerates first.
    dataMountedByLabel = assay.eq data.device "LABEL=data";
    dataLabelMatchesMkfs = assay.eq withDisko.fileSystems."/data".device "LABEL=${mkfsLabel}";
    dataIsBtrfs = assay.eq data.fsType "btrfs";
    dataCompressed = assay.eq (builtins.elem "compress=zstd" data.options) true;
    # RAID5 refuses to mount with a member missing. Without nofail that fails local-fs.target
    # and drops a headless host into an emergency shell nobody can reach.
    dataIsNofail = assay.eq (builtins.elem "nofail" data.options) true;

    # With nofail, an unmounted /data is an empty directory on root; NFS must refuse to serve
    # it rather than let rw clients write into it.
    nfsRequiresDataMount = assay.eq cfg.systemd.services.nfs-server.unitConfig.RequiresMountsFor "/data";

    scrubsData = assay.subset cfg.services.btrfs.autoScrub {
      enable = true;
      fileSystems = ["/data"];
      interval = "monthly";
    };

    initrdHasNvme = assay.eq (builtins.elem "nvme" initrd) true;
    initrdHasAhci = assay.eq (builtins.elem "ahci" initrd) true;
    loadsKvmAmd = assay.eq (builtins.elem "kvm-amd" cfg.boot.kernelModules) true;
    supportsBtrfs = assay.eq (cfg.boot.supportedFilesystems.btrfs or false) true;

    dataDirectories = assay.eq (builtins.filter (lib.hasPrefix "d /data/") cfg.systemd.tmpfiles.rules) [
      "d /data/archive 0755 tom users -"
      "d /data/docker 0755 tom users -"
      "d /data/scratch 0777 tom users -"
      "d /data/cache 0755 tom users -"
    ];
  }
