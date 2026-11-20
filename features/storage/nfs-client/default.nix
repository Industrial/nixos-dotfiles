# NFS client for fleet bulk storage: mounts the "nfs-server" host's /data at /mnt/<server>
# (mimir → /mnt/mimir), over Tailscale.
#
# Server and address come from common/fleet.nix — this feature never names a host. The
# server's export list is generated from the same "nfs-client" role, so enabling this feature
# on a host without the role mounts nothing useful: the server will refuse it.
#
# Mount behaviour, chosen so an offline server can never take a client down with it:
#   - x-systemd.automount + noauto: mounted on first access, not at boot. Boot never waits
#     on mimir or on Tailscale coming up.
#   - nofail: a failed mount does not fail local-fs.target / remote-fs.target.
#   - x-systemd.mount-timeout: an access while mimir is unreachable fails after 15s rather
#     than blocking.
#   - x-systemd.idle-timeout: unmounted after 10 idle minutes, so a later outage only bites
#     on the next access.
#   - hard (the default): an I/O in flight when the link drops waits and resumes instead of
#     returning EIO mid-write; that is the right trade for a read-write share of real files.
#
# Permissions: NFS sec=sys authorises by number. features/nixos/users pins the user's uid
# (1000) and the `data` group (gid 1111) on every host, and the server's /data is
# root:data 0770 with per-folder ownership tom:users — so the user reads and writes there as
# on mimir itself, and root on the client is squashed (root_squash) to nobody.
{pkgs, ...}: let
  fleet = import ../../../common/fleet.nix;
  server = builtins.head (fleet.withRole "nfs-server");
  serverIp = fleet.hosts.${server}.tailscaleIp;
in {
  environment.systemPackages = [pkgs.nfs-utils];

  boot.supportedFilesystems = ["nfs"];

  fileSystems."/mnt/${server}" = {
    device = "${serverIp}:/data";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "_netdev"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.mount-timeout=15s"
      "x-systemd.idle-timeout=10min"
    ];
  };
}
