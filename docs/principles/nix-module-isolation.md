---
slug: nix-module-isolation
rule_id: nix-module-isolation
severity: warning
---

# Principle: Each feature is a self-contained NixOS module

Every entry under `features/` must be independently importable as a NixOS
module. A feature may `import` sibling features it depends on (e.g.
`hermes-agent` importing `lean-ctx`), but must never reach outside its own
subtree for configuration values. Shared constants belong in `common/settings.nix`.

## Rationale

The whole-repo design explicitly avoids HomeManager to remain portable across
hosts. Tight coupling between features defeats that goal and makes it harder to
cherry-pick modules for new hosts.

## Acceptance test

Running `nix eval --impure .#nixosConfigurations.<host>.config` on any host
that does not import a given feature must not error due to missing references
from that feature.

## Anti-patterns

- Referencing `../other-feature/package.nix` from within a feature that does
  not explicitly import it.
- Putting global state (user home path, stateVersion) as literals inside a
  feature rather than threading them through `settings`.
