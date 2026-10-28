# V-268122 (CAT II) — NixOS system configuration files and directories must be owned by root.
#
# Scope is narrower than the title: the fix text says "to only use the root user for files
# under /etc/audit".
#
# VERIFY-ONLY, but provably so at eval time rather than by assertion of faith. On NixOS the
# /etc/audit tree is produced by the etc activation as symlinks into the Nix store, declared
# with user "+0" — uid 0, root. There is no chown to perform and no option to set; what there
# is, is a structural guarantee, and the colocated suite checks it against an evaluated
# system so a future nixpkgs change that moved /etc/audit to a mutable root-writable copy
# would fail the gate.
{...}: {
  # Intentionally empty — see above and ./V-268122.assay.nix.
}
