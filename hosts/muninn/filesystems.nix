# Additional filesystems not managed by disko
{...}: {
  fileSystems = {
    "/mnt/mimir" = {
      device = "mimir:/data";
      fsType = "nfs4";
      options = ["x-systemd.automount" "nofail" "timeo=14" "x-systemd.idle-timeout=600"];
    };
  };
}
