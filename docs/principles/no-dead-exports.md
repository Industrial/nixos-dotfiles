---
slug: no-dead-exports
rule_id: no-dead-exports
severity: warning
---

# Principle: Zero dead public exports

Every `pub` symbol in `rust/tools/` and `rust/common/` must have at least one
non-test consumer. Dead public exports degrade the roam health score and signal
unfinished or abandoned work.

## Rationale

`pub` means "this is part of the API." If nothing calls it, the API is lying.
Dead exports also confuse future agents that rely on the symbol graph to
understand intended behaviour.

## Acceptance test

`roam dead-code` reports 0 safe dead exports for the `rust/` subtree.

## Remediation

- If the symbol was scaffolding for future work: file a `bd` issue tracking the
  work and add a `#[allow(dead_code)] // tracked: bd-<id>` comment as a
  temporary exception, maximum 2 weeks.
- If the symbol is genuinely unused: delete it.
