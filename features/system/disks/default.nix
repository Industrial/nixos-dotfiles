{...}: {
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/e21dfbf4-4d89-4715-818f-d02ca94a6162";
    fsType = "ext4";
  };
  # fileSystems."/data" = {
  #   device = "/dev/disk/by-uuid/ff7184a2-7605-477e-bb14-8493e2889853";
  #   fsType = "ext4";
  # };
}
