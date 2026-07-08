# maestro — Local-first agent harness for the spec-to-ship loop
# https://github.com/ReinaMacCredy/maestro
#
# Provides `maestro` on PATH as a NixOS system package.
# Hermes Agent MCP server entry: not applicable (maestro is a CLI harness, not an MCP server).
#
# Quick start (in a project):
#   maestro init          # creates .maestro/ workspace
#   maestro setup        # scaffolds subdirectories + drops bundled skills
#   maestro spec new …    # author a product spec
#   maestro task from-spec .maestro/specs/…  # create + claim a task
#   maestro verify       # run the verification loop
#   maestro ship        # mark done and optionally attach PR URL
#
# Composable with Hermes `/goal`: run `maestro task claim` to pick up a structured task,
# then `/goal` within that session to drive the autonomous iteration loop. Maestro tracks
# task state + emits handoffs; Hermes `/goal` handles the judge-driven continuation.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
