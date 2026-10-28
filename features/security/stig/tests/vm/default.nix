# Aggregates every VM test spec into runnable NixOS tests.
#
# Exposed through the flake as checks.<system>.stig-V-<id> and run by `moon run stig-vm-test`.
#
# Spec groups are added here as they are written. Wave 2 starts with the seven controls that
# cannot be verified any other way (deferred.nix); the remaining checks follow by subsystem.
{
  pkgs,
  lib,
}: let
  harness = import ./harness.nix {inherit pkgs lib;};

  specGroups = [
    (import ./deferred.nix {inherit pkgs lib;})
  ];

  specs = builtins.concatLists specGroups;

  problems = builtins.concatLists (map harness.specProblems specs);
in
  if problems != []
  then
    builtins.throw ''
      features/security/stig/tests/vm: malformed test specs.
      ${builtins.concatStringsSep "\n" (map (p: "  - ${p}") problems)}
    ''
  else
    harness.mkTests specs
    // {
      # Metadata the report and the moon task read, so neither has to re-derive it.
      passthru = {
        ids = map (s: s.id) specs;
        count = builtins.length specs;
      };
    }
