# /etc as the upstream overlay (GH-185): an erofs metadata image under a mutable
# overlayfs, mounted instead of being written by setup-etc.pl. Off by default; enabled on
# no host. The measurement behind it: docs/history/20261122-etc-overlay-measurement.md.
#
# Upstream mounts the overlay over the old /etc and migrates nothing, so a host that
# enables it loses its machine-id, ssh host keys, NetworkManager connections, user
# database and the rest (measured, see the doc). This feature carries that state across:
#
#   - live, `switch-to-configuration` from a setup-etc.pl generation: an activation step
#     ordered before upstream's `etc` step (which mounts the overlay when /etc is not yet a
#     mountpoint) copies every stateful file from the live /etc into the upperdir;
#   - cold, the first boot into the overlay: an initrd unit ordered after the metadata
#     image is mounted and before rw-etc.service and sysroot-etc.mount does the same from
#     /sysroot/etc.
#
# Both start from a fresh upperdir: one left by an earlier overlay period that has since
# been left (/.rw-etc/.exited, written by ./exit.nix) is moved aside to /.rw-etc.stale-<t>,
# because the /etc that was used since is newer. Both copy only once per upperdir
# (/.rw-etc/.seeded), so a file deleted under the overlay does not come back at the next
# boot. What counts as stateful, and how it is copied: ./carry.nix.
#
# Leaving: ./exit.nix, which is part of features.nixos (on every host) rather than of this
# feature, because it has to run in the generation that does NOT enable the overlay.
#
# Rollback: `features.nixos.etc-overlay.enable = lib.mkForce false;` then switch (live) or
# boot: ./exit.nix copies the overlay's state back into the plain /etc.
#
# Health probe (on the host, as any user):
#   findmnt -n -o FSTYPE /etc                     # overlay
#   journalctl -b -o cat | grep 'etc-overlay:'    # what was carried; no FAILED line
{
  config,
  lib,
  pkgs,
  ...
}: let
  carry = import ./carry.nix {inherit pkgs lib;};
  etcTree = "${config.system.build.etc}/etc";

  # Run from the activation, live only: at boot the initrd unit below has done it, and
  # /etc is already the overlay (a mountpoint) by the time the activation runs.
  liveEntry = ''
    if [ -z "''${IN_NIXOS_SYSTEMD_STAGE1:-}" ] && ! mountpoint -q /etc; then
      if [ -e /.rw-etc ]; then
        mv /.rw-etc "/.rw-etc.stale-$(date +%s)"
      fi
      mkdir -p /.rw-etc/upper /.rw-etc/work
      chmod 0755 /.rw-etc /.rw-etc/upper /.rw-etc/work
      ${carry.carryIn} /etc /.rw-etc/upper ${etcTree} /.rw-etc/.carried && touch /.rw-etc/.seeded
    fi
  '';

  coldEntry = pkgs.writeShellScript "etc-overlay-cold-entry" ''
    set -u
    export PATH=${lib.makeBinPath [pkgs.coreutils]}
    if [ -e /sysroot/.rw-etc/.exited ]; then
      mv /sysroot/.rw-etc "/sysroot/.rw-etc.stale-$(date +%s)"
    fi
    mkdir -p -m 0755 /sysroot/.rw-etc/upper /sysroot/.rw-etc/work
    if [ ! -e /sysroot/.rw-etc/.seeded ]; then
      # Marked seeded only when the copy ran: a later boot tries again otherwise.
      ${carry.carryIn} /sysroot/etc /sysroot/.rw-etc/upper /run/nixos-etc-metadata /sysroot/.rw-etc/.carried \
        && touch /sysroot/.rw-etc/.seeded
    fi
  '';
in {
  system.etc.overlay = {
    enable = true;
    mutable = true;
  };

  system.activationScripts.etcOverlayCarryIn = lib.stringAfter ["users" "groups" "specialfs"] liveEntry;
  system.activationScripts.etc.deps = ["etcOverlayCarryIn"];

  # The kernel resolves an audit watch (`-w /etc/passwd …`, mimir's STIG identity rules)
  # when the rules are loaded. After a live switch the watches still point into the /etc
  # the overlay now hides (in) or the overlay that is gone (out), and writes to the
  # watched files go unaudited (measured: etc-overlay-live-switch-mimir). This trigger
  # changes the unit in both directions, so switch-to-configuration reloads the rules
  # after the activation has mounted or unmounted the overlay. A cold boot loads them
  # once /etc is in place anyway. With `security.audit.enable = "lock"` (`-e 2`) the
  # rules cannot be reloaded before a reboot: switch with `boot` there.
  systemd.services.audit-rules-nixos = lib.mkIf config.security.audit.enable {
    restartTriggers = ["etc-overlay"];
  };
  warnings = lib.optional (config.security.audit.enable == "lock") ''
    features.nixos.etc-overlay: the audit rules are locked (security.audit.enable = "lock"),
    so a live switch into or out of the /etc overlay leaves the /etc watches on the old
    /etc until a reboot. Switch with `boot` and reboot.
  '';

  boot.initrd.systemd = {
    storePaths = [coldEntry carry.carryIn] ++ carry.tools;
    services.etc-overlay-carry-in = {
      description = "Carry the stateful files of a setup-etc.pl /etc into the /etc overlay";
      wantedBy = ["initrd-fs.target"];
      before = ["rw-etc.service" "sysroot-etc.mount" "initrd-fs.target"];
      unitConfig = {
        DefaultDependencies = false;
        RequiresMountsFor = ["/sysroot" "/run/nixos-etc-metadata"];
        # Skip for a non-NixOS init=, as upstream's own units do.
        ConditionPathExists = "/etc-metadata-image";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${coldEntry}";
      };
    };
  };
}
