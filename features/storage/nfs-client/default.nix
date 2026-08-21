# NFS client utilities for fleet mounts (Drakkar, Huginn).
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [nfs-utils];
}
