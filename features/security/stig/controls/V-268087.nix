# V-268087 (CAT II) — NixOS must provide the capability for users to directly initiate a
# session lock for all connection types.
#
# Fix text installs `pkgs.vlock`, and the check is literally `which vlock`. The requirement is
# about the *capability existing*, not about forcing a lock — V-268086 is the one that imposes
# an idle timeout, and that one is disruptive and lives in the full profile.
#
# vlock covers the console/TTY case, which a graphical screen locker does not. That is why the
# control is satisfied by this package even on a host that already has a Wayland locker.
{pkgs, ...}: {
  environment.systemPackages = [pkgs.vlock];
}
