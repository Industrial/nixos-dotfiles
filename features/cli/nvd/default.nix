# nvd diffs the packages between two Nix system generations. Binary: nvd.
# Demoted (GH-153): features/cli/vdiff replaced it in cli-core and nothing in the repo calls
# it. Kept as the rollback: `features.cli.nvd.enable = true;` on a host brings it back.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nvd
  ];
}
