# vbump (rust/tools/vbump): per-input flake.lock updates. For each root input on its
# own, relock it (C++ `nix flake update <input>`), evaluate and dry-build every
# nixosConfiguration, diff each host's derivation closure (vdiff --json), and open one
# pull request per input. The scheduled path is .github/workflows/update-flake-lock.yml;
# by hand it is `bin/update/flake`, which runs vbump whenever it is installed, or
#   vbump run --dry-run [--input NAME]
# Rollback: with this feature off, bin/update/flake falls back to the all-inputs
# `nix flake update`; the workflow's own switch is the FLAKE_LOCK_UPDATER variable.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ../../../rust/tools/vbump/default.nix {})
  ];
}
