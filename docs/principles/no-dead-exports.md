---
slug: no-dead-exports
rule_id: no-dead-exports
severity: warning
---

# Principle: Zero dead public exports

Every `pub` symbol in `rust/tools/` must have at least one non-test consumer.
Dead public exports degrade the roam health score and signal unfinished or
abandoned work.

## Rationale

`pub` means "this is part of the API." If nothing calls it, the API is lying.
Dead exports also confuse future agents that rely on the symbol graph to
understand intended behaviour.

## Acceptance test

`roam dead` reports 0 safe dead exports for the `rust/tools/` subtree.

## Remediation

- If the symbol was scaffolding for future work: delete it or implement the
  consumer; do not leave `pub` symbols indefinitely unused.
- If the symbol is genuinely unused: delete it.
