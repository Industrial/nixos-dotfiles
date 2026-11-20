# Additional filesystems not managed by disko.
#
# None, deliberately. muninn is the work laptop: it holds no personal files, so it
# does not mount mimir's /data (and is not in mimir's NFS export list either — see
# common/fleet.nix). Do not add the /mnt/mimir mount the other hosts carry.
_: {
  fileSystems = {};
}
