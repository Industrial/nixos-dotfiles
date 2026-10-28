# V-268120 (CAT II) — NixOS audit configuration files must have a mode of 444 or less
# permissive.
#
# VERIFY-ONLY with an eval-time proof.
#
# The published fix text is truncated: it ends at "with the following command:" and then stops,
# giving no command at all. So there is nothing to apply literally even if one wanted to.
#
# On NixOS the answer is structural and stronger than 0444: every /etc/audit entry is a symlink
# into the Nix store, and store paths are read-only to everyone including root. A mode of 444
# on a mutable file can be changed back by root; a store path cannot be written at all while
# the store is mounted read-only.
#
# The suite asserts the structure rather than a mode string, because "symlink into an immutable
# store" is the fact that makes the requirement true here.
{...}: {
  # Intentionally empty — see above and ./V-268120.assay.nix.
}
