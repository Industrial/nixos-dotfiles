# V-268092 (CAT II) — NixOS must enable auditing of processes that start prior to the audit
# daemon.
#
# VERIFY-ONLY. Emits nothing, deliberately.
#
# The fix text says to add `boot.kernelParams = [ "audit=1" ]`. On current nixpkgs that is
# already done by nixos/modules/security/audit.nix, with this exact comment:
#
#   # A lot of audit events happen before the systemd service starts. Thus
#   # enable it via the kernel commandline to have the audit subsystem ready
#   # as soon as the kernel starts.
#   "audit=1"
#
# boot.kernelParams is a list, so declaring it again would put `audit=1` on the kernel command
# line twice. Harmless to the kernel, but it is duplicate state with no owner.
#
# Satisfied by V-268080 enabling security.audit. Checked in the colocated suite.
{...}: {
  # Intentionally empty — see above and ./V-268092.assay.nix.
}
