# V-268116 (CAT II) — NixOS journald directory and logs must be group-owned by
# systemd-journald to prevent unauthorized read access.
#
# VERIFY-ONLY, DEFERRED to the wave 2 VM test. Same reasoning as V-268115 — the two controls
# share one fix text, differing only in which half of `root:systemd-journald` they name.
#
# Registered in `security.stig.deferredVerification` so the report shows it as unverified.
{...}: {
  # Intentionally empty — see above and ./V-268116.assay.nix.
}
