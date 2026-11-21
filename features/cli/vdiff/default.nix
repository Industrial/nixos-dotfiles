# vdiff diffs the packages between two Nix closures or system generations,
# nvd's output read straight from the store database (rust/tools/vdiff).
# Binary: vdiff. `vdiff --generations system` diffs the last two generations.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ../../../rust/tools/vdiff/default.nix {})
  ];
}
