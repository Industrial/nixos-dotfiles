# V-268121 (CAT II) — NixOS system configuration file directories must have a mode of "0755"
# or less permissive.
#
# VERIFY-ONLY, DEFERRED to the wave 2 VM test.
#
# Fix text scope, again narrower than the title: "to use a mode of 755 or less for directories
# under /etc/audit".
#
# Unlike the *files* under /etc/audit — which V-268120, V-268122 and V-268123 prove are
# root-owned store symlinks at eval time — the containing directories are created by the etc
# activation script at boot, and their mode is not visible in the evaluated configuration.
# So this one cannot ride on the same structural argument as its neighbours.
#
# Registered in `security.stig.deferredVerification` so the report shows it as unverified.
{...}: {
  # Intentionally empty — see above and ./V-268121.assay.nix.
}
