# V-268116 (CAT II) — NixOS journald directory and logs must be group-owned by
# systemd-journald to prevent unauthorized read access.
#
# VERIFY-ONLY. Same reasoning as V-268115 — the two controls share one fix text, differing
# only in which half of `root:systemd-journald` they name.
#
# The published text is wrong, and provably so: **there is no `systemd-journald` group.**
# That is the daemon's name. The group systemd creates is `systemd-journal`, and running the
# fix text's `chown -R root:systemd-journald` verbatim fails with "invalid group". The VM test
# asserts both that no such group exists and that the real group is correct, so the divergence
# is evidence rather than an unexplained deviation.
#
# Registered in `security.stig.deferredVerification` because the group ownership of files
# under /var/log/journal is runtime state; the VM test in tests/vm/deferred.nix proves it.
{...}: {
  # Intentionally empty — see above and ./V-268116.assay.nix.
}
