# Session-Area Dissolution (2026-08-23) — third application of the context→service pattern

Commit c7b0e829. `contexts/session/` deleted; second bounded context fully
graduated after risk. This file records the session-specific decisions and
mechanics; the general pattern lives in `context-dissolution-pattern.md`.

## Final placement map

| Old (contexts/session/) | New home | Why |
|---|---|---|
| state.py → SessionState, SessionStatus | domain/session_state.py | Pure FSM. Its SessionStatus Literal became THE canonical one; domain/session_control.py (from risk dissolution) now imports it instead of defining a duplicate. |
| runner_protocol.py → SessionSnapshot | domain/session_snapshot.py | Frozen record, no deps beyond stdlib. |
| runner_protocol.py → Runner, RunnerMode | domain/runner.py | Structural Protocol port (house style). |
| runner_core.py → book_snapshot, refill, warmup math | services/forward_runner_support.py | Imports FT serializer (adapters) + catalog loaders (contexts) → cannot be domain. |
| forward_runner.py → ForwardRunner + selectors | services/forward_runner_service.py | Composes contexts/execution PaperPipeline → not domain-eligible. |
| runner.py → SessionRunner | services/session_runner.py | Orchestration (status/pair gate); kept as own service — multiple production consumers, absorption plan reversed on evidence. |
| multi_venue.py → MultiVenueRunner | services/multi_venue_runner.py | Registry typed on SessionRunner → service layer. |
| forward_session.py → ForwardSessionService | services/forward_session_service.py | Already service-shaped; moved nearly verbatim. |
| paper_session.py (677 L Nautilus harness) | adapters/driven/acl/nautilus/paper_session.py | Vendor-coupled machinery = driven adapter. |

Tests moved beside their modules (git mv): state_test → domain/,
runner_test + multi_venue_test → services/, paper_session_test +
paper_session_run_test + partial_failure_test → adapters/driven/acl/nautilus/.

## Key decisions and the evidence that drove them

1. Plan-vs-reality placement reversal. The approved plan put
   ForwardRunner/MultiVenueRunner in domain/. Reading the actual sources
   showed ForwardRunner imports contexts/execution.pipeline and snapshots via
   book_snapshot → trade_to_ft_dict (adapters). Rule: the purity gate
   (test_dissolved_context_domain_models_stay_pure in
   test/proofs/ddd_layout_import_rules_test.py) defines eligibility; check
   imports BEFORE writing the plan, and re-check after reading sources.
2. runner_core split. One module held a pure record AND infra helpers. Split
   by purity: record → domain, helpers → services. Do not relocate a mixed
   module wholesale to either side.
3. Absorption reversal. SessionRunner was slated for absorption into
   ForwardSessionService ("one consumer"). grep showed makers.py,
   MultiVenueRunner, backtest path, ~10 proofs. Kept as its own service;
   class name kept (wire stability).
4. Canonical Literal dedup. Two SessionStatus definitions existed after the
   risk dissolution (session_control.py) and session move (session_state.py).
   Canonical home = session_state.py; session_control.py imports it. When a
   dissolved context's type duplicates an earlier one, dedupe toward the more
   specific owner.

## Mechanics that worked

- Batch `git mv` for all relocations FIRST (history preserved), then one
  repo-wide python rewrite script with ORDERED substitutions: specific
  name-splits first (runner_protocol members went to two different homes),
  then whole-module moves, longest paths first. Finish with
  `grep -rn 'contexts.session' --include='*.py'` → must be zero.
- Two stragglers used `from andromeda.contexts.session import paper_session
  as ps` (package-import form the module-path subs missed) — add that form
  to the substitution list up front.
- E501 fallout: rewritten patch targets exceeded 100 chars. Fix = module
  constant `_PS = "andromeda.adapters.driven.acl.nautilus.paper_session"`
  then `patch(_PS + ".run_catalog_backtest", ...)`.
- `git rm contexts/session/runner_protocol.py` refused: "file has local
  modifications" — a concurrent agent had touched it mid-move. Read their
  version, diff mentally against the extracted domain copy (identical), then
  `git rm -f`.
- Concurrent agent's half-staged guard rename (contexts/venue/dry_run_guard.py
  → guards.py, kwarg live_submit_invoked → attempting_live) left two test
  call sites stale; completing the mechanical rename unblocked ft_17_75/17_80.
- Their staged files (venue_service{,_test}.py) again rode along in the
  commit snapshot — the "verify the commit after committing with
  `git show --stat`" rule caught it; harmless, attributed in the message.
- Baseline attribution: CLI serve-api failures + one ft_17_80 aggregate were
  proven pre-existing via a /tmp worktree at committed HEAD before blaming
  the moves; the two ft_17_75 cases were NEW and traced to the guard rename,
  not the dissolution.

## Verification at commit

Scoped suite 98 passed (domain + services + adapters + layout gates + all
protection/dry-run proofs), ruff clean on every touched file, zero
`contexts.session` references tree-wide. Follow-up commit a2a52e41 sorted one
import block ruff flagged post-hoc (session_control_test.py) rather than
amending shared history.
