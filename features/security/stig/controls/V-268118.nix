# V-268118 (CAT II) — NixOS systemd-journald logs must have a mode of 0640 or less permissive.
#
# VERIFY-ONLY, DEFERRED to the wave 2 VM test. Same reasoning as V-268117, for files rather
# than directories: journald sets 0640 by design and owns rotation.
#
# Registered in `security.stig.deferredVerification` so the report shows it as unverified.
{...}: {
  # Intentionally empty — see above and ./V-268118.assay.nix.
}
