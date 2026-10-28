# V-268115 (CAT II) — NixOS journald directory and logs must be owned by root to prevent
# unauthorized read access.
#
# VERIFY-ONLY, DEFERRED to the wave 2 VM test.
#
# The fix text concedes the point itself: "The systemd-journald logs are by design stored with
# root:systemd-journald owner and group respectively", and only then offers a chown for the
# case where something has drifted.
#
# There is nothing to declare. Adding systemd.tmpfiles rules for /var/log/journal would put us
# in a fight with systemd's own journal tmpfiles and with journald's rotation, which owns those
# files' lifecycle — a worse outcome than the requirement already being met.
#
# Crucially this is NOT the same as being proven: ownership under /var/log/journal is only
# observable on a booted machine. So the control is registered in
# `security.stig.deferredVerification`, which makes the report render it as *unverified*
# rather than Compliant. Its colocated suite enforces that registration.
{...}: {
  # Intentionally empty — see above and ./V-268115.assay.nix.
}
