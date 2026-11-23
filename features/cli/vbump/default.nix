# vbump (rust/tools/vbump): per-input flake.lock updates, the only lock updater
# (GH-247). For each root input on its own, relock it (C++ `nix flake update <input>`),
# evaluate and dry-build every nixosConfiguration, diff each host's derivation closure
# (vdiff --json), and open one pull request per input. The scheduled path is
# .github/workflows/vbump.yml (with --auto-merge: each PR merges itself once
# `ci / all-green` passes); by hand it is `bin/update/flake`, or
#   vbump run --dry-run [--input NAME]
# Rollback: restore the old update-flake-lock workflow from git history
# (docs/runbooks/updates.md §1).
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ../../../rust/tools/vbump/default.nix {})
  ];
}
