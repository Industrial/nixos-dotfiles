# V-268117 (CAT II) — NixOS systemd-journald directory must have a mode of 2755 or less
# permissive.
#
# VERIFY-ONLY, DEFERRED to the wave 2 VM test.
#
# Fix text: "The systemd-journald directories are by design set to 2755 mode", followed by a
# `find ... -exec chmod 2755` for drift. journald creates and maintains these directories; a
# tmpfiles rule competing for them would be the riskier choice.
#
# Directory modes under /var/log/journal are runtime state, so this is registered in
# `security.stig.deferredVerification` and reports as unverified until the VM test runs.
{...}: {
  # Intentionally empty — see above and ./V-268117.assay.nix.
}
