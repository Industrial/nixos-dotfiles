# V-268123 (CAT II) — NixOS system configuration files and directories must be group-owned by
# root.
#
# Same shape as V-268122, for the group rather than the owner. Fix text scope: "to only use
# the root group for files under /etc/audit".
#
# VERIFY-ONLY with an eval-time proof — the /etc/audit entries are declared with group "+0".
{...}: {
  # Intentionally empty — see above and ./V-268123.assay.nix.
}
