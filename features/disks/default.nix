{pkgs, ...}: {
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3269a0d8-8ccf-4f75-9bae-10a549389942";
    fsType = "ext4";
  };
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/ff7184a2-7605-477e-bb14-8493e2889853";
    fsType = "ext4";
  };
}