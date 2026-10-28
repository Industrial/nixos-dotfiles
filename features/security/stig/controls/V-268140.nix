# V-268140 (CAT II) — A sticky bit must be set on all NixOS public directories to prevent
# unauthorized and unintended information transferred via shared system resources.
#
# VERIFY-ONLY, DEFERRED to the wave 2 VM test.
#
# Fix text is `sudo chmod +t [Public Directory]` with the directory left as a placeholder — it
# does not enumerate what counts as a public directory, so there is no fixed set to declare.
#
# In practice the world-writable directories on a NixOS system are /tmp and /var/tmp, and
# systemd's own tmpfiles entries create both as 1777 (sticky already set). A blanket
# declaration here would either duplicate that or invent a list the STIG never specified.
#
# The honest implementation is the VM test: enumerate world-writable directories on a booted
# machine and assert every one has the sticky bit. That is also a stronger check than any
# static list, because it catches a *new* public directory some future feature introduces.
#
# Registered in `security.stig.deferredVerification` so the report shows it as unverified.
{...}: {
  # Intentionally empty — see above and ./V-268140.assay.nix.
}
