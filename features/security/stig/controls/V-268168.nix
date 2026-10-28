# V-268168 (CAT I) — NixOS must implement NIST FIPS-validated cryptography.
#
# Fix text: boot.kernelParams = [ "fips=1" ];
#
# ⚠ THE HIGHEST-RISK CONTROL IN THIS BENCHMARK. Read before enabling it anywhere.
#
# `fips=1` puts the kernel crypto API into FIPS mode, which refuses algorithms that are not
# FIPS-validated. On NixOS that is only half a story:
#
#   - NixOS ships no FIPS-validated crypto module, so the kernel enters a mode whose
#     validation claim the distribution cannot back. The control's stated purpose —
#     "FIPS-VALIDATED cryptography" — is therefore not actually met by setting the flag.
#   - Userspace is unaffected. OpenSSL, libgcrypt and the Nix daemon keep their own
#     algorithm sets, so the host is not FIPS end to end either way.
#   - Things break. MD5 and some SHA-1 uses are rejected in kernel space, which affects
#     dm-crypt setups, some wireless drivers, and anything relying on non-approved hashes.
#     On a LUKS-rooted host (V-268144) that is a real boot risk.
#
# It is implemented because it is CAT I and `full` must represent the benchmark, and it is
# kept out of base-safe for the reasons above. Like every control in this profile it is
# proven by a VM test rather than on hardware — and if it stops the VM booting, that is the
# finding, not a test failure to work around.
#
# Also note it is a kernel parameter: it cannot take effect until reboot, so the report will
# show it as "Configured (pending reboot)" on a host that has only switched.
{...}: {
  boot.kernelParams = ["fips=1"];
}
