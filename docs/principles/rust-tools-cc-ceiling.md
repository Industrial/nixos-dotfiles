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

The tools in `rust/tools/` are POSIX utility reimplementations. Their logic is
well-specified by POSIX standards; any CC > 10 is a sign the implementation has
drifted toward ad-hoc special-casing rather than structured argument dispatch.
High CC makes the tools harder to test to the 95% branch-coverage target in
TESTING.md.

## Acceptance test

`roam complexity-report --threshold 10` returns no symbols from `rust/tools/`.

## Remediation pattern

1. Extract each `match`/`if`-arm that handles a distinct flag into a
   `fn apply_<flag>_option(args: &mut Args, value: …) -> Result<()>` function.
2. The top-level `parse_args` becomes a flat dispatcher that calls helpers —
   nesting depth must not exceed 3.
