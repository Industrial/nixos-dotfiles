# Context → Service consolidation recipe (wave plan)

Class-level procedure for consolidating a bounded context into an application
service per `python/andromeda/ARCHITECTURE.md`. Executed twice now: pairlist
(b2f6dd2f→1494cdd3) and risk/RiskService (9a8a9535→521c9f49→ba2932cb,
completed 2026-08-23 with the full-absorption increment below).

## Picking the next target

Signals that a context is ready for consolidation:
- A stateful registry/dataclass in `contexts/<bc>/` that §5 of ARCHITECTURE.md
  cites as singleton-service material but has no service wrapper.
- Orchestration logic (high cyclomatic complexity) stranded as dataclass methods.
- Adapters importing the context directly (`adapters/**` reaching into
  `contexts.<bc>.*`) — consumers bypass any service abstraction.
- DI-wired components that no production code drives at runtime (dead wiring).
- Layering violations: `contexts/<bc>` importing from `andromeda.adapters`
  (§2 dependency direction says nothing below composition sees adapters).

Rank candidates by these signals; pick the one matching the canonical service
profile most closely.

## The three-wave pattern (one commit per wave)

**Wave 1 — introduce service + singleton wiring (additive only).**
- New `services/<area>_service.py`, exactly one class. Move the registry/book
  state and orchestration methods VERBATIM off the dataclass; add the unified
  query/gate method the consumers were missing. Engines/collaborators are
  constructor-injected; every query tolerates `None` ("not configured").
- Container: collaborators change Factory→Singleton (defaults unchanged); add
  `<area>_service = providers.Singleton(<Area>Service, ...)`; keep a
  transitional alias to the old provider name so existing tests still resolve
  (removed in Wave 2).
- Colocated `<area>_service_test.py`: dedup/id-monotonicity of the book, sync/
  rebuild per engine branch, gate truth table, None-tolerance, validation-error
  surfacing. Plus identity tests per §5 rule 4: two resolutions return the same
  object and injected consumers hold it.

**Wave 2 — migrate every consumer onto the service.**
- Makers/factories take the service instead of the raw type; adapter dataclass
  field KEEPS its old name when it means "the injected service slot" (e.g.
  `ApiApp.locks: RiskService`) — renaming fields breaks every constructor call
  site for zero architectural gain. Route bodies call the service.
- ApplicationContainer wires the service provider directly; drop the alias.
- Migrate proof/test files to construct engines + service explicitly.
- Pitfall learned: passing `risk_service=risk_service` to a factory whose
  downstream dataclass field is still named `locks` = TypeError at resolution;
  keyword must match the FIELD name, not the parameter concept.

**Wave 3 — removal, layering fix, docs.**
- Delete the old registry class; if the remaining record violates one-class-
  per-file naming (§3.3), `git mv` the file first (history preserved) then
  rewrite contents; upgrade any import-smoke-only test into real assertions.
- Shared taxonomy/constants that caused a context→adapters import move to a
  `domain/<name>.py` shared-kernel module; the old adapters module becomes a
  pure re-export shim (explicit names + `__all__`) so all existing adapter-side
  imports stay valid with zero churn.
- Extend `test/proofs/ddd_layout_import_rules_test.py` with a gate scoped to
  the consolidated context ONLY — grep first: other contexts may violate the
  same rule today (catalog did); note rollout path in the gate docstring.
- Update ARCHITECTURE.md: services tree gains the file; §1-style canonical
  table gains the area row(s).

## Verification discipline

- Scoped pytest over touched paths + `ruff check <paths>` green between waves;
  full-package suite at REVIEW. Coverage floor ≥95% is immutable (moon.yml).
- Let ruff `--fix` sort import blocks ONLY in files whose imports you touched;
  pre-existing I001/F401 in untouched files stays (no drive-by fixes).
- If the always-run commit gate is deadlocked by failures outside your diff,
  follow the id-workflow SHIP protocol (pristine-HEAD worktree proof, single
  `core.hooksPath=/dev/null` commit with evidence). Expect formatters to have
  rewrapped YOUR staged files during the blocked run — inspect and re-add.
- With a concurrent second agent committing to the same checkout: explicit
  paths in `git add`, re-check `git log` before each commit, scope verification
  with `-k 'not their_feature'`, and attribute residual redness via
  `git diff HEAD -- <their files>` + clean-worktree reproduction before
  claiming your waves are verified.

## Full absorption ("all functionality into the service")

When asked to move EVERYTHING from a consolidated context into its service:
consolidate dispatch ownership, not file locations — engines/records/ports
stay put as domain classes; only orchestration enters the service (risk
increment ba2932cb):
- A remaining engine joins as a constructor param (`max_drawdown`) plus a
  container Singleton; session-side effects go through the context's existing
  port (`observe_equity(equity, session)` → `SessionControl.pause`), never by
  importing session state directly.
- Unified event intake: `record_exit(pair, *, exit_reason, when,
  profit_ratio, candle_index)` fans out to all held engines and returns
  per-engine engagement (`{"stoploss_guard": True, ...}`); engines whose datum
  is absent (None) are silently skipped, not errors.
- Keep gate semantics separate: pair-scoped `blocks()` vs session-halt
  `observe_equity()` — max-drawdown pauses the session, it never blocks a pair.
- Test-semantics trap: an engagement flag evaluated AT the exit candle is
  trivially True there; window semantics belong to the gate, so assert them
  through `blocks(pair, candle_index=...)`, not through record_exit's return.
- When shared test files carry another agent's WIP, put container-identity
  tests in YOUR service test file (constructing the nested container directly)
  instead of staging the shared composition test — explicit-path staging still
  ships every foreign hunk inside a file you touch.

## Next candidate

`SessionState` (contexts/session/state.py) — cited by ARCHITECTURE.md §5 as a
singleton-state example, still a bare dataclass wired via SessionContainer.