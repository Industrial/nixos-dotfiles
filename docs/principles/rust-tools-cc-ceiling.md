---
slug: rust-tools-cc-ceiling
rule_id: rust-tools-cc-ceiling
severity: warning
---

# Principle: Cognitive complexity ceiling of 10 for Rust tools

No function in `rust/tools/` may have a cognitive complexity (CC) score above
10. Functions approaching the ceiling must be split into named helper functions
that each have a single, stated responsibility.

## Rationale

The `rust/tools/` workspace currently contains `oomkiller`, a memory-pressure
daemon. Its control flow (process enumeration, threshold checks, signal delivery)
should stay linear and testable. CC > 10 indicates ad-hoc branching that makes
the 95% coverage target in `rust/tools/TESTING.md` harder to sustain.

## Acceptance test

`roam complexity --threshold 10` returns no symbols from `rust/tools/`.

## Remediation pattern

1. Extract each distinct branch (threshold check, process selection, kill path)
   into a focused helper with a descriptive name.
2. Keep top-level orchestration (`daemon_iteration`, `main`) as flat dispatch —
   nesting depth must not exceed 3.
