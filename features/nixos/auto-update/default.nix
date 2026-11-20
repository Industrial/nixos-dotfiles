# Unattended updates on this fleet belong to comin, and only to comin
# (docs/adr/0002-comin-pull-convergence.md, docs/adr/0006-update-policy.md).
#
# This feature used to hold a nightly root timer that ran `nix flake update` and
# `nixos-rebuild switch` in ~/.dotfiles. It was never turned on, for three reasons:
#   * root cannot update a user-owned git flake (libgit2: "repository path is not
#     owned by current user");
#   * a nightly switch fights interactive sessions and RAM;
#   * it would activate an unreviewed lock from a local working tree: a third
#     activator next to comin and deploy-rs, and one that comin reverts within
#     300s anyway.
# The replacement: .github/workflows/update-flake-lock.yml opens a lock-bump PR,
# the operator reviews and merges it, and comin converges every host from main.
#
# What is left is the guard: nixpkgs' own unattended upgrader must stay off,
# because it would be exactly that third activator.
{config, ...}: {
  assertions = [
    {
      assertion = !config.system.autoUpgrade.enable;
      message = ''
        system.autoUpgrade.enable is set, but comin is this fleet's only unattended
        activator (ADR-0002, ADR-0006). Lock bumps arrive as reviewed PRs from
        .github/workflows/update-flake-lock.yml; hosts converge from merged main.
      '';
    }
  ];
}
