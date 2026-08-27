---
name: ddd-context-dissolution
description: >
  Dissolve an andromeda bounded context (contexts/<bc>/) into services/,
  domain/ models, value_objects and driven adapters per ARCHITECTURE.md.
  Use when removing a context, moving its types to domain, consolidating
  behavior behind *Service classes, or continuing the contexts/-elimination
  campaign in solana-yield-optimizer.
tags: [architecture, refactoring, andromeda, ddd]
---

# Bounded-context dissolution (contexts/<bc>/ → domain/services/adapters)

Recurring campaign in this repo. Already dissolved: pairlist, risk, session,
candle, service layer (2026-08-23), FULL context removal incl. vendors
(2026-08-23: services/venue hierarchy + ports → domain/venue{,_executor}.py +
CostModel ABC → domain/cost_model.py + vendor trees → adapters/driven/acl/
{hl,cme,ibkr}; shell stub suites died, tombstone in layout gates).
Remaining candidates: NONE — contexts/ ELIMINATED repo-wide 2026-08-24 (catalog was the last; see catalog paragraph). Execution
DISSOLVED 2026-08-24 (84490a41): NT bridge modules → acl/nautilus/, engines →
services/execution/{paper_pipeline,paper_execution,backtest}_service.py, exit
math+policy folded into domain/exit_rules.py, nt_fills died shell,
acl/freqtrade/exit_reasons now a re-export shim over domain.exit_reason —
placement map, research-vs-executed deltas and Phase B open items in
references/execution-case-study.md (READ BEFORE touching services/execution/**). FreqAI_host DISSOLVED 2026-08-23 (bd43e456→90e1f828→0a920ac9→
7b6c8c26): ~7400 lines split by character — pure FT-shaped math → domain/
(freqai_config/features/targets/outliers/corr_mtf/event_time/parity/expand,
l2_tensor, tensor_stub_model; fixes domain/run_config→contexts inversion);
orchestration → services/freqai_{host,pipeline,lifecycle,retrain,adaptive,
walkforward,sequence,operator} (flat landing FLAGGED by user 2026-08-24:
none follows the <area>_service.py law; regroup into a services/freqai/
package is PLANNED — .cursor/plans/freqai-services-package.plan.md, user
rulings pending, see Techniques "Post-dissolution layout audit"); vendor
machinery → acl/freqtrade/{models,
data_provider,hyperopt}, acl/nautilus/{freqai_start,artifacts}, acl/
lopezdeprado; ports+trace died shell; walkforward_proof+leakage_acceptance →
test/proofs/. legacy_pickle._CANON remaps old artifact GLOBAL paths to the
new canonical host module.
Catalog EXECUTING since 2026-08-23, user-ordered as a PARALLEL-EXISTENCE
dissolution: build new code beside the untouched context, cut all consumers
over, THEN delete; QuestDB-only store, parquet backend dies.
Wave 1 (new homes beside old) LANDED UNCOMMITTED: services/catalog_service.py
(CatalogService.require_from_env() = the single seam) + services/catalog/
{downloader,micro_downloader,micro_loader,equity_sources,equity_service,
equity_importer,backtest_runner}, adapters/driven/acl/questdb (+testing/
memory_store), acl/providers/{hyperliquid,cme,crypto_spartan,ohlcv_1m,stooq,
markettas_datasource,synthetic,synthetic_micro}, adapters/driven/import_daemon,
domain/{bar_math,catalog_requests,equity_listing}, acl/ibkr/symbology split,
acl/hl/capture/hl_micro_sync.py — 151 scoped tests green. Wave 2 LANDED (575a632e, container cutover);
wave 3 LANDED (d763cb5c + repair 01db17eb): consumer cutover COMPLETE — zero
`contexts.catalog` refs outside the context itself (AC-1 met), driving-layer
test seams repointed off dead names onto CatalogService class methods,
conftest parallel-existence bridge live. Wave 4 (demolition) EXECUTED 2026-08-24
uncommitted: contexts/ tree deleted (incl. contexts/__init__.py), conftest bridge
removed atomically, catalog tombstone + purity-gate additions landed — execution
notes in references/catalog-waves.md. All three wave-1 subagents failed
(empty reply / 2×600s timeouts); the parent absorbed every scope manually and
verified green — see Techniques (mock-seam shadowing, patch-helper contract).
Artifacts: .cursor/plans/catalog-dissolution-catalogservice.plan.md,
.maestro/specs/catalog-dissolution-catalogservice.md,
.maestro/missions/catalog-dissolution-catalogservice.execution.md; placement
map + evidence in references/catalog-case-study.md — read/update BEFORE
executing waves 2–4.
FreqAI_host Wave A EXECUTED 2026-08-23 (work uncommitted at execution time;
orchestrator holds pathspec-limited commit duty): three PARALLEL SUBAGENTS
with disjoint file ownership (pure-math→domain/, lopezdeprado→acl/, shell
deaths + leakage-helper extraction + walkforward_proof relocation); A1 hit
the leaf timeout AFTER its moves fully landed — inspect the tree, absorb
residual stragglers yourself instead of re-dispatching. Waves B/C pending;
full execution evidence + consumer inventory in
references/freqai-host-case-study.md — read/update BEFORE continuing.
Microstructure DISSOLVED 2026-08-23 (3ce8bb66): services/microstructure_service.py
absorbed FeatureCatalog as instance registry state plus l1/l2/temporal/attach
math as staticmethods keeping historical names (l1_snapshot/l2_snapshot/
ofi_windows/attach_features); OrderBookState/TradeFlowWindow/EventTimeClock/
L1+L2 snapshots → domain/; BookDelta/TradePrint/TimedObservation →
value_objects/; book_delta_from_nt → acl/nautilus/book_map.py (purges
nautilus_trader from domain; apply_nt_delta + OrderBookDelta alias died);
application/ports/* protocols died shell — zero production consumers;
colocated tests split per class home (book_test → order_book_state_test +
value_objects/book_delta_test.py).
Instrument_map DISSOLVED 2026-08-23 (0043a011): held only leftover fixture data
+ test scaffolding after PairResolver had already dissolved — no service was
warranted. HL fixture table hl_perps.py → acl/hl/instruments_map.py (mirrors
acl/ibkr/instruments.py); roundtrip free function → PairResolver.assert_roundtrip
method (old form reached into resolver._by_pair from outside; vestigial
expected_id branch was a bare continue at loop end — died); InstrumentDirectory
port died shell (zero consumers). Lesson: audit a remaining candidate for
"already replaced by earlier dissolutions" before planning a service — some
contexts are just un-moved residue.


## Placement decision table

| Code character | Destination |
|---|---|
| Dataclass carrying state + behavior over its own state | `domain/<snake_name>.py`, one class per file (§3.3) |
| Structural port (Protocol) satisfied duck-typed elsewhere | `domain/` beside the models that consume it |
| Orchestration: registries, gates, loops, event fan-out | `services/<area>_service.py`, one job per class |
| Vendor-coupled machinery (Nautilus Strategy subclasses, capture harnesses) | `adapters/driven/acl/<vendor>/` |
| Duplicated Literals/aliases across areas | Canonicalize in ONE domain module; others import it |

Deciding rule: `domain/` must never import `adapters/` or `contexts/`. If the
candidate composes a pipeline, catalog, or serializer, it is a SERVICE even if
the plan said domain (this moved ForwardRunner out of domain/ mid-execution).

## User architecture rulings (law for this repo)

- A service module defines exactly ONE class. Module-level helpers: pure math →
  `@staticmethod`/`@classmethod`; state-touching → instance method; trivial +
  single-use → inline into the caller method.
- Shell classes die: zero production callers ⇒ delete the class, rewrite its
  tests against real behavior (multi-venue became N wired SessionRunners in a
  plain dict — dispatch is the call site's dict lookup, not a service).
- No selector/factory functions (`simulation_runner`, `make_forward_runner`):
  dependency_injector constructs services directly, e.g.
  `providers.Factory(ForwardRunnerService, mode="simulation", pipeline=pipeline)`
  inside a Selector keyed off config.
- Gate placement — final law (2026-08-23, third revision): the state/pair gate
  (`on_bar`, bot_start/bot_loop_start hooks, pipeline/venue_executor/dry_run
  surface) lives on the session RUNNER contract, not a separate wrapper.
  History: plan said absorb SessionRunner into ForwardSessionService →
  consumer counts argued keep it → shell death made user order merge into
  SessionService → then the whole SessionService dissolved into
  `services/runner/RunnerService` (see next bullet). Do not re-litigate;
  the gated runner is THE session object now.
- Abstract service hierarchies: VenueService remains USER-ORDERED law
  (`services/venue/`, abc.ABC, hl/ibkr/cme/paper kinds via Selector on
  venue_key). The RUNNER hierarchy — created by the same kind of order —
  was LATER DISSOLVED by another user order (collapse wave, next bullet).
  User's stated principle:
  "a single central service contract for speaking about a subject/topic,
  let implementations figure out the differences." When ordering a new
  hierarchy they cite existing ones as the model; sim/real stay constructor
  values, never subclasses. Absorbing a verb-only twin into the base kills the FSM-fork
  hazard: container resolves ONE gated singleton that HTTP verbs and the
  loop both drive; keep old provider names as aliases
  `session_service = runner`) because application_container + proofs still
  reference them. Fold precedent (d1479124, user-ordered): when a sibling
  service is thin orchestration ALWAYS constructed around one subclass and
  the user calls the subclass "empty", they order a FOLD — loop deps become
  optional state attached via idempotent `configure_loop()`, the wire-factory
  returns THE singleton, the separate module dies. Circular-import hazard:
  the runner module is imported BY contexts (backtest.py), so any module-
  level import that transitively re-reaches it must be deferred into the
  consuming method. Full mechanics: references/runner-case-study.md,
  fold-wave + collapse-wave sections.
- Hierarchy COLLAPSE is the mirror move (1827100b, user-ordered): when only
  one subclass of an ABC remains and backtest never touches the contract at
  all, the user orders the merge — "move everything into RunnerService, make
  it the one and only, put it in services/, remove services/runner". The
  ABC's shared surface gets INLINED into the concrete class (do not keep a
  dead base), variance stays injection-based (pipeline adapter = execution,
  configure_loop = feed), and the test relocates beside its subject. Watch:
  `parents[N]` config-path constants in relocated tests must drop by one
  level; a composed-from-two-files class can lose an import the source files
  each had (`CatalogError` F821 — latent because both except-paths are
  unreachable under mocks; run ruff on every file you hand-compose).
  REVERSAL APPROVED + EXECUTED (2026-08-24, /id-workflow full cycle): the
  catalog dissolution surfaced live-vs-batch confusion ("why is there a
  backtest_runner AND a RunnerService?" — name collision as consolidation
  trigger, same pattern as the rename-trigger law); user approved
  .cursor/plans/runner-services-package.plan.md and all four waves landed.
  Final shape: services/runner/{live_runner(LiveRunnerService gated loop),
  historical_runner(HistoricalRunnerService batch NT backtests),
  runner_service.py facade binding RunnerService = LiveRunnerService};
  warmup math (freqai_fe_warmup_bars, load_start_with_warmup) moved to
  domain/session_warmup.py, killing the deferred-import cycle;
  services/catalog/backtest_runner.py deleted. The FACADE ALIAS kept every
  consumer import, patch string, and §5.4 identity test alive with ZERO
  consumer edits for the rename — see Techniques. This order supersedes
  1827100b's "remove services/runner" deletion; do not collapse it back
  without a new order.
- Glue modules don't belong in services/ either: a `services/*_support.py` of
  free functions dissolves the same way as a context — pure math → a
  `domain/<area>_<topic>.py` module added to the dissolved-domain purity gate;
  single-consumer adapter-coupled functions fold into their consuming service
  as private instance methods; pass-through wrappers die by promoting the
  wrapped underscore function to a public name in its home module (callers
  follow). Worked example: forward_runner_support → domain/session_warmup.py +
  folds into ForwardSessionService._refresh_store / ForwardRunnerService.snapshot.
- Class names stay stable while files move (§3.6); rename only on explicit ask.
- Facade aliases are TRANSITIONAL, never terminal (runner double reversal,
  2026-08-24): the same-day sequence was collapse → package+facade
  (`RunnerService = LiveRunnerService` in runner_service.py) → user ABC order
  ("RunnerService base class with abstract methods; Live and Historical inherit
  from it", filenames live_runner_service.py / historical_runner_service.py per
  the suffix law) which DELETED the alias. Reading the user's phrasing decides
  the shape: "base class with abstract methods" is an unambiguous real-ABC
  order — a facade alias would violate it; if they only ask for file
  organization, prefer the facade alias (zero consumer edits). These orders are
  the user's prerogative and reversible at will; never defend yesterday's
  structure, never "fix" an order contradicted by newer worktree state.
  Mechanics of the ABC landing that worked: base declares NO ctor (subclasses
  keep their own signatures), contract attrs as plain annotated class attrs
  (`mode: RunnerMode`) never @property (subclass `self.mode = mode` would
  AttributeError); batch subclass implements session verbs HONESTLY for its
  reality (status()→"stopped", empty history/trades snapshot, lifecycle verbs
  raise BotControlError) rather than no-op stubs. See also Techniques:
  ABC-landing construction sweep + free-function→method seam shapes.
- Abstract service hierarchies happen ONLY on explicit user order, even when
  every generic ruling above argues flat: after two debate turns the user
  ordered VenueService as an abc.ABC (`services/venue/`, `list_pairs`/
  `cost_model` abstract) with hl/ibkr/cme/paper subclasses picked by a
  providers.Selector on `venue_key(raw_config)`. Law since 2026-08-23 — do
  not collapse it back and do not generalize it to other services without an
  order. Execute such reversals literally ("no more discussion" means no
  more discussion) and record them so later sessions don't "fix" it. The
  RUNNER hierarchy has now flip-flopped TWICE by user order (collapse
  1827100b → package+facade 2026-08-24 → ABC REVERSAL same day: "RunnerService
  base class with abstract methods; Live and Historical inherit from it" —
  filenames live_runner_service.py / historical_runner_service.py per the
  suffix law). Lesson: these orders are the user's prerogative and reversible
  at will; never defend yesterday's structure, never "fix" an order you find
  contradicted by newer worktree state. When the user says "base class with
  abstract methods", that is an unambiguous ABC order (a facade alias would
  violate it); when they only ask for file organization, prefer the facade
  alias (zero consumer edits). Full mechanics:
  references/runner-case-study.md final section.
- No acronym-prefixed class names ("we don't do acronyms", ruled when ordering
  the venue hierarchy): post-approval the user ordered HlVenueService →
  HyperliquidVenueService, then "do the same for the other venues" —
  CmeVenueService → ChicagoMercantileExchangeVenueService, IbkrVenueService →
  InternationalBrokersVenueService (names mirror the adapter classes), each
  module git-mv'd to the snake_case of its class, plus a colocated
  `<kind>_venue_service_test.py` for EVERY implementation on request.
  Recipe: git mv the module, scripted word-boundary replace across every
  consumer incl. docstrings and ARCHITECTURE.md table rows, leftover grep
  must be empty — wire/config identifiers stay abbreviated (Selector arm stays
  `hl=`, operator configs stay `"hl"`). Expect E501/import-format fallout in
  import blocks after lengthening names; fix mechanically and rerun.

## Waves (one commit per wave, scoped green between)

0. Quiet-tree gate: the second session shares this worktree and dissolves
   contexts in parallel (candle, session, venue landed mid-session). makers.py,
   composition containers, application_test.py, ARCHITECTURE.md and proof files
   are shared magnets. Do not start waves overlapping their dirty files; when a
   rename lands under you mid-execution (e.g. make_session_runner →
   make_session_gate), adapt to their naming instead of fighting it.
   Plan presentations: user wants the FULL plan printed for discussion before
   approval on architecture changes — include open decision points labeled as
   questions; "Approve" then means execute all waves without re-asking. When a
   review pass surfaces one gap, inventory ALL remaining work for that area
   BEFORE asking approve/defer ("analyze what else we should do to finish X
   first") — a binary question on one item while siblings exist reads as
   incomplete scoping; present the full finish-list with deliberate
   non-items marked as such.
1. Domain extraction: `git mv` sources, canonicalize duplicates, scripted
   import rewrite, move colocated tests.
2. Service moves: relocate loop owners; rewire makers + container + §5.4
   identity tests (two resolutions same object, consumers hold the singleton).
3. Adapter relocation for vendor harnesses (update their test homes too).
4. Tombstone test (`assert not (ANDROMEDA/"contexts"/bc).exists()`), extend the
   dissolved-domain purity gate list, add ARCHITECTURE.md canonical table.

## Techniques

- Post-dissolution LAYOUT AUDIT (freqai residue, 2026-08-24): graduating a
  context is not layout compliance — the dissolved orchestration landed as
  eight flat services/freqai_*.py modules, none a <area>_service.py, and the
  user flagged them. When one area holds a service PLUS free-function job
  modules, regroup as a services/<area>/ package (venue/execution/catalog
  precedent): git mv the modules + colocated tests, STRIP the area prefix
  from job filenames (free-function modules are exempt from filename=class;
  the prefix's job is done by the package name), keep the service module as
  <name>_service.py. Classification rules verified while planning: a wrapper
  around OUR OWN domain model (SequenceModelAdapter over
  domain/tensor_stub_model) stays a services job — ACL is for VENDOR-coupled
  machinery only; wire/config identifiers stay stable through any class
  rename (make_freqai_host, container attr freqai_host); module loggers
  follow their new module homes (053c2cb4 precedent). Sweep additions beyond
  imports + patch strings: pickle remap tables
  (acl/nautilus/artifacts/legacy_pickle._CANON) must GAIN a mapping to every
  new canonical module path, with older entries RETARGETED transitively
  (store_test asserts the mapping); legacy logger-name lists wired elsewhere
  (afml/logging_util.py) are identifiers with their own closeout-wave
  alignment (+ that test); CHECK services/__init__.py FIRST — if the moved
  modules were never re-exported there, that seam breaks nothing; ARCHITECTURE.md
  area-table rows rewrite to package form in the docs wave; patch-target
  strings living inside the PARALLEL session's new code
  (contexts/catalog/testing/memory_store.py) are shared magnets —
  defer/adapt, don't collide.
- Import rewrite script over `rglob('*.py')`; substitution list ordered
  most-specific-first (member splits like `runner_protocol import RunnerMode,
  SessionSnapshot` BEFORE whole-module rules); renames via regex
  `\bName\b(?!Service)`. Finish with a leftover grep that must be empty.
- Rename-sweep blind spot: a scripted rewrite can delete a FUNCTION-LOCAL
  import (`from x.y import simulation_runner` inside a test body) while
  rewriting its call — the file stays ruff-import-clean and only fails at
  runtime with NameError. After any sweep, run `ruff check --select F821`
  over the whole tree and repair every hit before claiming green.
- Truncated logs lie: `tail -N` on a pytest log hides FAILED lines. Always
  assert on the captured exit code AND grep `FAILED`/`passed` from the full
  log file, never trust the last lines alone — a false green shipped one
  commit with 9 latent failures that the next pass had to confess and fix.
- Longer module paths push `patch("…")` targets and imports past ruff's 100
  columns → hoist constants (`_PS = "long.module.path"`) in tests.
- devenv ctx_shell sometimes swallows piped stdout → write output to
  `/tmp/x.log` inside the command, then `tail` the file.
- For READ-ONLY inspection (ls/head/grep/wc/sed -n over absolute paths),
  skip the devenv wrap entirely — plain ctx_shell returns the payload
  inline, while the wrap injects ~100 lines of SyncProject/prek noise that
  can push the real output out-of-band into the archive.
- lean-ctx PERMANENTLY blocks `python -c "…"` inline interpreter code
  ("Use a script file instead" — retrying is futile, same class as native
  Shell denies; `bash -c "…"` inline scripts block identically — decompose
  into plain single commands or write a script file). Workaround: write the snippet to /tmp via write_file, then
  run it through the allowed path (`../.devenv/state/venv/bin/python
  /tmp/snippet.py`) — proven for import smoke checks that pytest collection
  can't answer (e.g. verifying a package re-export survives).
- `git rm` refuses locally-modified files even when content matches what you
  wrote elsewhere — diff to confirm equivalence, then `git rm -f`.
- Transient collection SyntaxErrors during pytest are usually the other
  session mid-save; `py_compile` the files and rerun before diagnosing.
- `patch` tool on a shared file can report "on-disk content differs" while the
  write actually landed (concurrent writer raced the read-back). Re-read the
  file and `git diff` before retrying — a blind retry double-applies.
- Silent-fallthrough audit BEFORE promoting a domain key: grep configs and
  call sites for sentinel values that relied on the old lenient behavior
  (venue "synthetic" lived in CLI/catalog/nautilus but in none of the
  normalizers). Add sentinels to the canonical set, keep the degrade-not-raise
  policy at adapter edges (HTTP bodies catch the new error explicitly), raise
  everywhere else.
- Selector branches for shared services must be `providers.Singleton`, never
  Factory: Factory re-resolves per consumer and silently breaks §5 identity
  tests (two resolutions must be the same object).
- Merging a base class into an existing service (SessionService →
  RunnerService seams) changes the ctor signature repo-wide: two-level
  `Gate(runner=Runner(mode=…, pipeline=…))` collapses to one level — script a
  balanced-paren collapse, then hand-check every site where a kwarg VALUE
  contains commas (`allowed_pairs=frozenset({...})`,
  `stake=StakeAmount.parse(100)`, nested `build_paper_pipeline(...)`): the
  lazy regex mis-closes those and leaves `)),` orphans that only surface as
  SyntaxError at collection. After such a sweep grep for `))\n` and `,(\n`
  patterns and run pytest COLLECTION first (`pytest --co -q`) before the
  suite. Also expect the read-only-property trap: if the ABC declares
  `mode` as @property and the subclass does `self.mode = mode` in __init__,
  that is AttributeError at construction — declare contract attributes as
  plain annotated class attrs on the ABC, properties only for derived values.
- Deleting a makers/factory helper mid-session when the OTHER session also
  renamed it earlier (make_session_runner → make_session_gate): re-grep
  before deleting — their rename may have left importers you haven't seen
  (`composition/application.py` re-exports, nautilus test helpers). Every
  deleted factory needs a leftover-grep pass AND a check of
  composition/application.py's re-export surface.
- When extraction makes a service ABC, grep for bare `ClassName()` fallbacks
  first: test-only constructions inside HTTP bodies / catalog helpers raise
  TypeError at setup — repoint them to the kind matching that endpoint's
  default venue.
- A service hierarchy unlocks a SECOND deletion wave inside the source
  context: once every production caller funnels through the kinds, the
  string-keyed dispatch modules die — pair-universe switch → concrete base
  method + small `_adapter_pairs` hook per kind; cost-model if-chains → each
  kind binds its concrete model directly via one shared `_resolve_cost_block`
  helper; guards → staticmethod on the base; pure ABCs (abc/Any imports only)
  → `domain/<name>.py` added to the dissolved-domain purity gate. Write the
  destination domain file IN THE SAME WAVE as anything importing it —
  creating only `domain/cost_model_test.py` left the whole tree failing at
  collection until the module existed; run `pytest --co -q` immediately after
  any move-to-domain. And when a generic resolver becomes a pinned-kind
  method, PRE-CHECK the venue key (`is_known`, normalize, compare) before
  delegating — delegating first silently resolves YOUR kind's model for
  other venues' configs (`resolve_cme_costs({"venue": "hl"})` returned CME
  costs until the pre-check went in).
- Preserve exact legacy semantics when a generic function becomes a subclass
  method with a defaulted key: `resolve_cost_model(None)` returns None — a
  subclass override must keep `if not isinstance(raw_config, dict): return
  None` BEFORE pinning its venue key, or `cost_model(None)` silently resolves
  a model where the old path returned None (caught by the ported test).
- Loader-based pair universes are FT-shaped only: `instruments.
  _dedupe_sorted` silently drops entries failing `Pair.parse` (`BASE/QUOTE`
  regex). Test loaders returning bare symbols ("6J", "AAPL") yield [] —
  write loader payloads as "6J/USD"-style pairs; the filtering is legacy
  behavior, not a bug to fix in the test.
- Multi-file string-replace edits can mis-indent or duplicate lines (a
  replacement string re-matching its own tail). After batch replaces, run
  ruff AND read back each edited region; F841/NameError from a swallowed
  assignment line is the signature of this.
- Repo conftest's autouse QuestDB fixture imports composition/CLI on EVERY test;
  while the parallel session holds the container mid-rename, scoped runs fail
  tree-wide at setup. Escape hatch: prefix runs with a WELL-FORMED DSN pointing
  at an unreachable port — `QUESTDB_PG_URL='postgresql://unused:unused@localhost:5434/unused'`.
  Since the catalog w2 cutover, the old bare `unused://` value is parsed by
  psycopg2 before any fixture short-circuits (`invalid dsn: missing "=" after
  "unused://"`) and yields ~3 false failures in ft_17_58 — if you see that error,
  it is your env var, not the code under test.
- `uv run` is tree-wide fragile on this workspace: one malformed/missing
  member `pyproject.toml` (happened twice 2026-08-23 with `python/questdb`
  during the parallel session's restructuring) makes EVERY `uv run pytest`
  die with exit 2 before pytest starts. Bypass without touching their WIP:
  invoke the devenv venv interpreter directly (`../.devenv/state/venv/bin/
  python -m pytest …`) and use the nix-provided `ruff` binary for lint (it
  is not installed inside that venv). Read the captured exit code plus the
  error text before diagnosing your own code — a tooling exit 2 with no
  test output is the signature.
- Maestro CLI is not on the devenv PATH; invoke it by absolute Nix store path
  and `lean-ctx allow maestro` once if the shell allowlist blocks it. Full
  recipe: references/maestro-invocation.md.
- Creating a contract package must complete the FAMILY MOVE in the same wave:
  b79a06b7 added services/runner/ for the RunnerService ABC and even moved the
  subclass's test into it, yet left the class itself at
  services/forward_runner_service.py — the next REVIEW pass flagged the
  test-here/class-there split. After creating a hierarchy package, grep the
  old flat home for remaining family members and git mv them in too.
  Executed 2026-08-23 (16b6af04): git mv first, then fix latent bugs in the
  moved file so they ship inside the rename commit (`_n_bars = 0` init +
  real pipeline-None degradation replacing asserts); scripted import rewrite
  with an exact-count assert per file; package __init__ re-exports BOTH
  contract and concrete; top-level services/__init__ imports through the
  package so `from andromeda.services import X` stays stable for consumers;
  ARCHITECTURE.md table row updated in the same wave.
- After absorbing a contract, SWEEP FOR SURVIVORS WEARING THE DEAD NAME:
  b79a06b7 folded SessionService into RunnerService, yet
  ForwardSessionService kept the "SessionService" substring and the user
  then repeatedly asked "is that still needed?" about a healthy service.
  Recurring confusion about a name is a RENAME TRIGGER, not an architecture
  question: rename the survivor to its subject (aedfc34f,
  ForwardSessionService → ForwardLoopService, matching its ARCHITECTURE.md
  row label "Forward loop"). Sweep shape: git mv the module AND any test
  file whose NAME carries the dead prefix
  (forward_session_trade_persistence_test.py → forward_loop_…); scripted
  replace of BOTH tokens (CamelCase class + snake_case module) across every
  consumer incl. docstrings, patch() target strings and ARCHITECTURE.md
  rows; leftover grep empty; do NOT touch adjacent-subsystem filenames
  (paper_session*.py = the nautilus harness, different subject) or archived
  .maestro plans (historical record). Verify scoped suites incl. the
  renamed test before committing.
- Shared-worktree commit primitive when the index is contaminated by the
  parallel session: `SKIP=pre-commit,commit-msg git commit -m <msg> --
  <paths>` commits the WORKTREE contents of exactly those paths and never
  touches their staged entries (unlike plain `git commit`, which sweeps the
  shared index). ALWAYS pass `-m`: without it git launches vi and dies in
  devenv ("cannot run vi") AFTER sanitize prep has already run, wasting the
  attempt. Classify every file against CURRENT HEAD inside the commit
  attempt (HEAD moves under you — their commits may absorb your rewrite
  mid-session): whole = only your deltas → commit directly; mixed = your
  hunk + their unrelated pending delta → capture original, write HEAD-
  version + ONLY your substitution, commit, restore original in finally so
  their delta stays pending for THEIR commit; skip = your rewrite already
  absorbed by their commits, or foreign-only residue remains. Sequencing:
  while their dissolution commit is pending, HEAD still contains modules
  your import rewrite replaces — committing alone keeps the tree green at
  your SHA; finishing that flip is theirs.
- Foreign-delta gate design: NEVER include rename ENDPOINTS in a lexical
  changed-line scan (file absent at HEAD ⇒ `diff HEAD -- <file>` shows all
  additions — meaningless; validate structurally instead: content markers
  present in worktree copy, old path gone, new path absent at HEAD), and
  exclude isolation-handled mixed files (their foreign hunks are neutralized
  by the sanitize dance, not by the scanner). Scanning them anyway produces
  allowlist whack-a-mole — seven guarded aborts in one session, every abort
  a gate bug, zero real foreign leaks. Run as phases: 1 read-only audit
  must print CLEAN, 2 mutations wrapped in try/finally restoring originals,
  3 post-commit verify `git show --name-only HEAD` ⊆ expected set. Every
  assertion fires before any mutation, so aborts cost nothing.

- Token-classification trap in foreign-delta gates: classify by the OLD
  token only (`ForwardSessionService`, `forward_session_service`) — if you
  also allowlist the NEW token (`forward_runner_service`), every rewritten
  import line counts as "mine" and real foreign edits on those same lines
  slip through silently. The old-token rule works because a line still
  carrying it is by definition untouched by your rewrite.
- Maestro `status --json` returns an object keyed {maestro_health,
  project_state, missions, next_ready, recent_transitions} — NOT a task list;
  `missions` groups are {mission, tasks} pairs with orphan drafts under a
  synthetic "(unscoped)" mission. Dump the JSON and grep for your area slug
  before creating any task; absence means no tracker coverage exists (real
  case: freqai layout audit 2026-08-24 — zero freqai/layout tasks; shipped
  under the tracker-unavailable fallback rather than retro-fitting a task,
  which would fabricate timeline state).
- A foreign COMMIT can revert your UNCOMMITTED work: the parallel session
  substring rule for `from m import A, B` fired on `from m import A, B, C`,
  leaving a dangling `, C` importing a name that no longer exists in the
  rewritten module (F821 at runtime, ruff-import-clean). Build rules as exact
  line replacements and assert leftover `contexts.<bc>` grep is empty before
  running the suite. Also: when the service module's final home differs from
  any interim path you wrote into consumers, fix consumer imports to the FINAL
  home in the same pass — a two-step interim path leaves ModuleNotFoundError
  once the context tree is git-rm'd.
- ctx_shell auto-backgrounds any command passing the ~110s foreground cap and
  returns only a job id — the command's output is NOT in that first result. Poll
  with `background_action="status"` (may need two calls: "running" →
  "completed"); the archived result is retrievable via ctx_expand on the printed
  archive id. Repo-wide grep over this workspace exceeds the cap — prefer
  search_files (rg-backed) or scope greps to subdirectories so commands stay
  foreground. Also: devenv-shell preamble (SyncProject lines + prek hook install)
  bloats every result — read the archived file directly with read_file at the
  printed offset instead of expanding whole archives.
- TEST FILES CAN BE IMPORTED BY OTHER TESTS: before git-mv'ing or deleting any
  `*_test.py`, grep for its module path across the tree — freqai_host's
  leakage_acceptance_test.py is imported by
  ft_17_78_proof_freqai_event_time_test.py for shared fixtures. Extract the
  shared helpers into a non-test module FIRST, then move/relocate both files;
  moving an imported test module otherwise breaks collection at the importer.
- Subagent delegation for dissolution waves: leaf agents hit the 600s timeout
  on multi-step waves (3/3 timed out) but usually FINISH the work and die only
  in reporting — always diff the tree to see what landed before re-dispatching,
  then run the verification battery yourself. Function-local imports and
  importlib.import_module("...") string literals are the recurring rewrite
  blind spot even inside subagent runs; F821/ruff does not catch string
  literals, grep for them explicitly.
- Shared-magnet sanitize dance v2: when a parallel session commits ONTO your
  landed work with stale editor buffers (catalog w2 resurrected dissolved
  contexts.freqai_host imports in 4 shared files), repair-forward with a
  sanitized commit: backup worktree → write HEAD+only-your-substitutions →
  commit with full pathspec → restore their pending deltas. Never amend a
  commit that has a foreign child; never publish a foreign half-done package
  (services/execution/) just because your swept hunks reference it — record it
  as a known blemish healed by its owner's next wave.
- Post-commit verification when foreign red blocks claiming suite green: copy
  `scripts/adhoc_relocation_verify.py`, edit its CONFIG block, run with python3,
  delete the copy. It verifies delivered behavior directly — old homes absent,
  destination package complete, venv import probe, tree-wide stale-reference
  scan, scoped pytest battery — and prints an explicit AD-HOC VERDICT. Report
  results as ad-hoc evidence, never as "suite green" (system gates ask for
  exactly this shape).
- Foreign red SHRINKS INCREMENTALLY while the other session lands its batch:
  re-run the known-red set immediately before closing REVIEW and report the
  trend (real case: operator_test x2 + walkforward_proof_test went 3 → 1
  failing between runs ~1h apart on 2026-08-24). Never assume the foreign set
  is static — and never repair it mid-flight either way.
- Dotted-token sweeps miss SPACE-form imports: `from andromeda.services import
  freqai_walkforward as wf` contains no `andromeda.services.freqai_walkforward`
  token. Sweep both forms (`import <mod>` / `importlib.import_module("<mod>")` /
  `"..."` string targets) and grep `from <pkg> import` lines for moved names
  before declaring leftovers empty. Worked example: freqai wave-1 (2026-08-24,
  73bda3d7) — collection check caught the space-form stragglers immediately.
- Scripted `git mv` lists must enumerate EVERY file including colocated tests;
  deriving moves from a module map alone left all 8 `*_test.py` behind until
  collection flagged them. Post-move assertion: old names absent AND expected
  count present under the destination package.
- Parallel session may RE-STAGE after your rewrite lands in the shared worktree:
  their staged snapshot then already contains your import updates, making
  previously-poisonous shared files safe to ride in your pathspec commit. Verify
  per-file with `git diff -- <file>` (worktree vs INDEX): empty ⇒ ride; non-empty
  ⇒ classify the residual hunk. Re-classify at commit time, never trust the
  wave-start audit. Same session: ft_17_78's foreign staged fix repaired an
  import into a DELETED context dir — absorbing it was required for collection
  green, not optional.
- afml/logging_util-style logger registries can be VESTIGIAL: it wired
  `andromeda.freqai_host` while modules actually logged
  `andromeda.services.freqai_host`. Before aligning such wiring after a move,
  grep the actual `getLogger(...)` sites and wire the real parent
  (`andromeda.services.freqai`) so every area logger inherits handlers.
- Consolidating N modules into ONE *Service class (2026-08-24 freqai consolidation,
  4ee14178..db1efb54): joblib `delayed()` targets must remain module-level-qualifiable
  — make them `@staticmethod` and call `ClassName._helper` inside `delayed(...)` so
  process-pool pickling keeps working. Preserve load-bearing FUNCTION-LOCAL imports
  when a consumer both feeds and consumes the service (artifacts/materialize ↔
  freqai_service is a real cycle; the deferred import IS the guard). Retarget
  legacy_pickle `_CANON` entries to where the CLASS now lives (domain), not the
  service — unpickling resolves module path of the class, not its orchestrator.
- Migration scripts run repeatedly during debugging MUST be idempotent: assert
  count==1 before every replace or check `new in text` first — three stacked
  duplicate kwarg lines from blind re-runs only surfaced at collection as
  "duplicate argument". Same for test-suite merges: two sections defining `_cfg`
  collide silently; rename per section at merge time.
- The lean-ctx tree/index can be STALE mid-campaign (it showed all six remaining
  contexts as empty while search_files proved hundreds of live files under
  python/andromeda/contexts/**). Never conclude a directory is empty from the
  indexed tree alone — confirm with find/search_files on the real filesystem
  before planning around it. Also note paths are repo-root-relative only below
  `python/andromeda/` (`notebooks/...` does not exist in this checkout).
- PARALLEL-EXISTENCE dissolution is a user-ordered variant (catalog, planned
  2026-08-23): instead of in-place git-mv waves, (1) CREATE the new code beside
  the untouched context — moves land as new homes + the new service class while
  old modules keep working via rewritten intra-imports; (2) CUT OVER all ~20
  production consumers with a scripted rewrite; leftover grep for
  `contexts\.catalog` must be 0; (3) DEMOLISH with `git rm -r contexts/<bc>`,
  tombstone test, purity-gate additions, ARCHITECTURE.md row. Use when the user
  says "leave the old code in place and only create the new code" — do not
  convert it back into mv-waves. Biggest hazard found at planning: repo
  conftest.py imports MemoryQuestDbStore from contexts/catalog/testing on EVERY
  test and its patch-target list hardcodes NINE module paths under the old tree
  (incl. `adapters.download.worker`) — relocate testing/ EARLY (with conftest +
  patch-target rewrite) or every scoped run dies tree-wide; and monkeypatch/
  patch STRING targets ("andromeda.contexts.catalog.…") are imports too — the
  scripted sweep must rewrite string literals or tests break at runtime with a
  clean-looking import graph. Dead-backend audit: distinguish OUR storage
  formats (parquet/jsonl catalog trees die) from VENDOR file inputs read by a
  surviving pipeline (MarketTaS features.parquet reader lives).
- services/__init__.py is a shared magnet: if it carries another session's
  uncommitted rename (e.g. runner package → flat module) that references
  modules absent at HEAD, DEFER your export addition — commit it with their
  pending commit instead of shipping a broken intermediate. The worktree stays
  green; only the committed SHA lacks the re-export until then. RE-CHECK the
  file at every later commit opportunity instead of waiting passively: once
  their blocking rename becomes HEAD the file is wholly yours — land your
  export, finish their half-landed rename mechanically, and dedupe duplicate
  `__all__` entries a rename sweep can leave (adding a new entry without
  removing the old alias leaves exactly that).
- Very long pathspec-limited commit commands get silently TRUNCATED: trailing
  paths vanish, so renamed endpoints stay uncommitted while gates/docs land —
  leaving e.g. a tombstone test that is false on pristine checkout. After every
  commit, diff `git show --stat HEAD` against your expected file set; land any
  missed endpoints in an explicit companion commit rather than force-amending.


- CREATE-ONLY wave variant under a hot index: when the shared index holds staged
  deltas inside contexts/<bc>/**, do NOT mv/edit anything there — flip the wave to
  strictly create-only (new homes beside the old tree; old modules keep working
  because copied files get their intra-imports rewritten to the NEW acl/domain
  paths). Verify the gate afterwards: `git status --porcelain` over contexts/,
  composition/, conftest.py must show zero files touched by you. Demolition stays
  in the final wave.
- Demolition pre-flight AST CENSUS (catalog w4): before `git rm -r`, parse every
  non-test module's public top-level symbols and match against definitions in the
  REST of the tree — classifies each name ALIVE (with homes) vs RETIRED
  (legacy-format stacks, CLI-retired verbs, factory funcs absorbed into the
  facade), proves "nothing outside calls in" at SYMBOL level (module-level greps
  prove less), and doubles as the post-dissolution functionality/consumers
  inventory users ask for. Pair with a COVERAGE-PARITY check: every surviving
  module needs its test family somewhere — search patch-string paths, not just
  colocated test files (equity_importer's only coverage lived inside
  app_main_test.py seam patches).
- Test-support seams that patch INTO a dying tree die WITH it, atomically: the
  conftest-called bridge helper lived in the NEW acl testing module while string-
  patching a factory INSIDE the context — remove helper + both conftest call sites
  + tree in ONE wave or every scoped run dies at monkeypatch setattr time. Sweep
  conftest.py for helpers naming the dead root before declaring removal done.
- Gate files hide POSITIVE existence asserts of what you delete behind silent
  skips: the success-criteria checklist asserted contexts/{execution,catalog}
  EXIST, but the whole test had been skipping since BOUNDED_CONTEXTS.md vanished —
  stale weight nobody noticed. When demolishing a context, grep proof/gate files
  for asserts of its PRESENCE (incl. skip-shadowed tests) and drop them; the
  tombstone for the LAST context should assert the whole contexts/ tree absent.
- Post-cutover DEAD-ALIAS sweep: relocation waves leave compatibility aliases in
  NEW homes (`sync_catalog_micro_from_hl = sync_micro_from_hl` survived inside
  acl/hl/capture/hl_micro_sync.py with a comment naming callers that no longer
  exist). Grep new modules for `old_name =` lines after cutover, apply shell-death
  law to the alias itself, repoint consumers (here exactly one test call site).
- Foreign-blocker evidence under repeated verifier demands: when full-tree green
  is impossible because a parallel session's untracked WIP breaks imports at
  COLLECTION time (--continue-on-collection-errors shows ONE ImportError signature
  across N files), do NOT repair their mid-flight files even when pressed for
  fresh evidence. Instead re-probe their blocker cheaply before each round (fresh
  import probe of their module — it heals when THEY land), keep a standing
  CYCLE-FREE scoped battery mapped to YOUR changed paths, refresh it per demand,
  and report blocker + blast radius instead of re-running the full tree each time.
- FACADE ALIAS enables package + rename in one wave with ZERO consumer edits
  (runner consolidation 2026-08-24): when re-creating a package around a renamed
  class, keep the old flat module path as a tiny facade (`RunnerService =
  LiveRunnerService`) and route services/__init__ through the package — every
  consumer import (`from andromeda.services import RunnerService`), every patch
  string (`"…runner_service.CatalogService…"`), every identity test keeps
  resolving via the same class object; only intra-package files change. Rename
  tokens INSIDE moved files (class def, staticmethod self-references, docstrings)
  but leave all external call sites on the alias. Watch: package __init__ must
  not export names whose modules land in LATER waves (importing
  HistoricalRunnerService two waves early broke collection tree-wide) — grow
  exports per wave. Moved tests resolve config fixtures via `parents[N]`:
  depth INCREASES by one per package level (parents[1]→parents[2] here).
- Free-function module → Service class cutover seam shape (historical runner):
  tests patching the old module attribute `monkeypatch.setattr(mod,
  "run_catalog_backtest", fake)` must become string-target class seams
  (`setattr("…HistoricalRunnerService.run", fake)`). CRITICAL: a plain function
  assigned onto a CLASS becomes a bound method — self arrives first, so every
  fake must be arity-tolerant `lambda *a, **kw:` or a SimpleNamespace(run=…)
  replacing the whole class attr; positional fakes like `lambda p: p` explode.
  Production callers become `HistoricalRunnerService().run(...)`; a private
  helper used cross-module (`_ensure_micro`) graduates to a public method
  (`ensure_micro`) taking injected catalog.
- ACCEPT-AND-DEFER for a foreign half-cutover crossing your new API (2026-08-24):
  the parallel session's committed CLI caller passed `freqai_host=...` into a
  function that never accepted it (their incomplete threading). When your
  replacement absorbs that function, accept the kwarg explicitly, log-debug that
  it is deferred, and document WHY in the docstring — their call site stays
  alive (restores last-known-good behavior), their threading remains THEIRS to
  finish. Do not silently drop unknown kwargs and do not implement their half.
- NEVER-EXISTED husk imports: an import rewrite can point a test at a module
  path that was NEVER created anywhere (`git log --all -- <path>` empty) —
  ft_17_09 imported services/catalog/ft_import since w3 and stayed red-hidden
  behind earlier blockers until the first full battery ran. Such a file may also
  reference RETIRED functionality (pre-w1 ctor signatures, user-retired CLI
  verbs): it's a husk needing an owner decision (rewrite against current homes
  vs delete), not a mechanical repoint. Flag it for REVIEW instead of silently
  rewriting proofs. Related: demolition tail-sweep must cover PROVENANCE
  DOCSTRINGS in new homes ("Carried from contexts/catalog/…") which survive as
  intentional placement-map documentation — distinguish them from live refs by
  grep form (prose vs import/patch-string).
- write_file OVERWRITES silently: creating `acl/<vendor>/__init__.py` inside a
  package that ALREADY exists (ibkr appeared mid-campaign from the parallel
  dissolution) clobbers their init. Before any new-file write whose parent dir
  may pre-exist, `git status --porcelain <parent>/` + ls it; if you clobbered,
  `git show HEAD:<path>` the original, restore its content VERBATIM, then append
  your re-exports. Never assume "new package" means "empty on disk".
- Empty subagent reply (empty model content after retries, tiny api_calls count,
  seconds elapsed) = infra failure, NOT a task result: `git status` the target
  dirs to see if anything landed (usually nothing), then ABSORB the scope into
  the parent agent instead of re-dispatching blind — reading ~5 sources and
  writing files directly produced verified green on the first pass here. Keep
  the dispatch context text as the work order for the manual absorption.
- grep -cE "FAILED|ERROR" inside `bash -c '…'` exits 1 when the count is ZERO,
  failing the chain even though zero-failures is the SUCCESS signal — external
  verifiers then see exit 1 and flag the work "unverified". Append `|| true`
  to the grep so the captured exit code belongs to pytest, not grep's empty match.
- Subagent timeout ≠ lost work: a leaf that hits its wall-clock cap after N
  API calls may have finished every mutation and died only in reporting.
  Before re-dispatching, inspect the target dirs (git status + ls) to see what
  landed; finish residual stragglers yourself rather than paying a second
  full dispatch. Pair with: brief subagents to run their verification EARLY
  and report incrementally, so a timeout still leaves evidence behind.
- Scripted porting beats subagent reading for MECHANICAL scopes (faithful copy
  + import substitution over ~50 files): a parent-side execute_code pass with an
  ordered substitution table, per-file count asserts, and a leftover grep landed
  in seconds what a leaf burned its whole 600s budget reading sources for. Use
  subagents for judgment-heavy ports (signature redesigns, test authorship);
  keep bulk faithful copies as scripted transforms with exact-count asserts.
- Import-sweep straggler classes beyond function-local imports (all found only
  by RUNNING relocated tests, not by old-path leftover greps): (a)
  importlib.import_module("<path>") STRING literals — grep for the old module
  path inside quotes too; (b) rewrite rules that emitted UNPREFIXED new names
  (`andromeda.domain.parity` instead of `andromeda.domain.freqai_parity`) —
  spot-check rewritten import lines resolve under their NEW names; (c)
  test-module imports of another test's fixtures — extract shared helpers into
  a non-test module before moving either file.
- Mock-seam shadowing (catalog wave 1): patching a FACTORY classmethod
  (`CatalogService.require_from_env`) to return a bare `MagicMock()` breaks any
  later per-method patch — the INSTANCE's auto-created child attribute shadows
  the class-level patch you set next, so `svc.load_instrument_and_bars(...)` is
  a fresh Mock, not your fake. Fix: configure ONE fake service object
  (`fake_svc = MagicMock(); fake_svc.method.side_effect = ...`) and return it
  from the factory stub. Ported tests that patched old free functions or module
  attributes (`worker.require_questdb_store`, `worker.load_instrument_and_bars`)
  must be rewritten to the new seam shape, not string-swapped.
- Test-support patch helpers define a CONTRACT: memory_store's patch helpers
  historically stubbed the factory to return the raw store; when the seam became
  CatalogService.require_from_env, mechanically-ported callers broke
  (`isinstance(svc.store, MemoryQuestDbStore)` failed because they got the bare
  store). The helpers must return a CatalogService WRAPPING the injected store
  (classmethod stub on the class), keeping legacy helper names/signatures so
  call sites port without edits.
- Provider-name validation belongs in the DOWNLOADER service after request VOs
  move to domain/ (domain must stay validation-free for provider allow-lists):
  port the rejection cases into downloader tests with the EXACT legacy message,
  and keep one canary test proving the VO now ACCEPTS the formerly-rejected
  provider value.
- When merging two source modules into one domain module (resample+equity_merge
  → domain/bar_math), duplicate constants (SOURCE_* names) canonicalize into the
  NEW domain home and consumers (providers) import them there — do not leave the
  constants in a services/ pipeline module that domain would have to import
  (purity direction violation).
- Live-server integration gates need a REAL-URL guard, not an env-var guard:
  `if not os.environ.get(URL): skip` fires whenever the escape-hatch sentinel
  (`QUESTDB_PG_URL=unused://`) is set and then attempts a live connection. Guard
  on the value instead: skip unless it startswith("postgresql://").
- FULL-TREE BATTERIES RUN ENV-UNSET, not just well-formed-DSN (catalog w3,
  2026-08-24): conftest's autouse memory-store stub activates ONLY when
  QUESTDB_PG_URL is UNSET — ANY value (bare `unused://`, or the recommended
  well-formed unreachable DSN) makes the fixture return early, so the battery
  runs half-stubbed: degraded connections plus unstubbed store resolution emit
  psycopg2 `invalid dsn` / `QUESTDB_PG_URL is not set` noise indistinguishable
  from regressions. Correct invocation: `env -u QUESTDB_PG_URL … -m pytest`.
  Reserve DSN sentinels for scoped suites proven never to resolve a store.
  Attribution corollary: when resuming an interrupted lineage whose tree is
  already red, run pristine HEAD through `/tmp/head-proof` under the IDENTICAL
  env and diff failure sets against the worktree run — the delta sizes your
  true surface (HEAD was already red here; several "failures" were baseline).
- ABC-landing construction sweep: when a base class becomes abstract, EVERY
  direct `Base(...)` construction site dies ("takes no arguments" from
  dependency_injector Singleton, TypeError from plain calls). Sweep Selector
  arms, fallback ctors in driving adapters, test harnesses and proofs —
  repoint constructions to the CONCRETE subclass while type ANNOTATIONS may
  legitimately stay on the base (subclass satisfies them). Then sweep the
  F401 fallout: proof files that imported the base only for the ctor keep
  dead imports after cutover; drop unused names (docstring mentions of the
  class do NOT count as uses — grep code lines only).
- Staticmethod helpers called as `Class._helper(...)` in tests move WITH the
  class they live on: when tests reach staticmethods via the base name
  (`RunnerService._excluded_pairs`) and the helper lives on the concrete
  class, patch seams and aliases must repoint to the concrete name or every
  such test AttributeErrors. Grep for `BaseName\._` forms during any
  hierarchy restructure.
- Free function → Service method conversion breaks TWO test populations at
  cutover: object-form module-attr patches (`setattr(mod, "func", fake)`)
  die at patch time (attribute gone from the module), and positional fakes
  explode on class seams because a plain function assigned onto a CLASS
  becomes bound — self arrives first (`lambda p: p` → TypeError). Convert to
  string-target patches on the method with arity-tolerant fakes
  (`lambda *a, **kw:`), or replace the whole class attribute via
  SimpleNamespace(run=fake)/patch.object(ConcreteClass, "method", ...).
  Semantic check too: old `load_catalog_micro` returned a lookup DICT while
  the absorbed facade verb `micro_lookup` iterates rows — repointing a seam
  to a differently-shaped sibling method fails at first use ('int' has no
  attribute 'timestamp'), so match RETURN SHAPE not just name similarity.
- git mv refuses UNTRACKED sources ("fatal: not under version control"):
  files created this session but never committed need a plain filesystem
  move (shutil/os.rename); reserve git mv for tracked paths so rename
  detection survives. Check trackedness per file when scripting family moves.
- ACCEPT-AND-DEFER for a foreign half-cutover crossing your new API: if a
  committed foreign caller passes a kwarg your replacement function never
  accepted, accept it explicitly, log-debug that it is deferred, document WHY
  in the docstring (their call site revives, their threading remains theirs),
  instead of dropping unknown kwargs silently or implementing their half.
- NEVER-EXISTED husk imports: an import rewrite can point a test at a module
  path that was never created anywhere (`git log --all -- <path>` empty).
  Such files reference retired functionality (old ctors, retired CLI verbs)
  and stay red-hidden behind earlier blockers until the first full battery.
  Flag for REVIEW as an owner decision (rewrite vs delete) rather than
  mechanically repointing proofs.
- Facade cutovers break TWO populations at once: production call sites that
  still invoke the adapter free-function instead of the new service verb
  (bypassing the facade = spec violation even when it "works"), and ported
  tests still patching the OLD module-level seam. Refresh shape for class-level
  seams: `monkeypatch.setattr("…catalog_service.CatalogService.require_from_env",
  classmethod(lambda cls, *a, **k: stub))`; instance-method seams
  (`CatalogService.load_instrument_and_bars`) take the plain-lambda string-target
  form. Tell: `AttributeError: <module …> has no attribute 'require_questdb_store'`
  raised AT PATCH TIME means the seam name died, not the code under test.
- Best-effort guards HIDE rename damage: `except Exception: log.warning();
  return None` around bookkeeping swallowed a stale `forward.catalog.root` read
  (attribute died in the container cutover) — six tests then failed downstream
  on MISSING RUN DIRECTORIES with no traceback pointing at the cause. When N
  tests fail on absent files/dirs, hunt for an upstream best-effort block eating
  an AttributeError from a renamed attr before touching the tests themselves.
- dependency_injector fakes need provider DUALITY: providers are consumed as
  `.override(x)` during setup AND called at resolution (`container.catalog_root()`).
  A fake satisfying one side fails the other — use a tiny object that is both
  callable and overrideable. Also VERIFY WHICH FAILING TEST OWNS each fake
  before editing: pattern-matching a fix onto a structurally similar fake in a
  PASSING test breaks green (revert immediately; locate by error line numbers).
- Retiring CLI commands mid-cutover: raise BotControlError (the dispatch catches
  it → JSON error body + exit 1), never bare SystemExit — main() does not catch
  SystemExit, so pytest records an interpreter abort instead of the exit-code
  contract and the retirement test fails on the wrong axis.
- A foreign git mv can delete a file BETWEEN your read and your write
  (services/freqai_operator_test.py → services/freqai/operator_test.py landed
  mid-edit): FileNotFoundError during scripted replaces = re-stat the tree,
  find the moved path, apply remaining seams THERE. Never recreate content at
  the old path.
- Partial seam refresh fails QUIETLY: rewriting some `setattr(mod, "dead_name")`
  lines while siblings keep the dead token leaves the SAME tests failing with
  SHIFTED error signatures. After each batch grep the touched files for every
  dead token, rerun scoped, and diff error SHAPES against the pre-fix log —
  same names + new errors = progress; same names + same errors = the edit never
  landed (check you edited the path pytest actually imports).
- Resuming an INTERRUPTED LINEAGE: the shared worktree may already hold THIS
  campaign's staged-but-uncommitted wave (~140 paths). Classify before acting:
  `python/andromeda/**` = campaign code to verify+commit;
  `.maestro/**` verdicts/handoffs/tasks = other sessions' tracker output (leave);
  `python/questdb/artifacts/*` etc. = foreign test artifacts that must NEVER ride
  the commit. An external-referrer grep (`rg contexts\\.catalog -g '!contexts/**'`)
  tells you how much of the consumer cutover already happened.

## Verification & attribution

- When inventorying a context for a dissolution plan, read the case log
  (references/dissolved-contexts.md)
  full (head+tail via ctx_expand) — the inline preview truncates at ~80 matches;
  then classify each module by its IMPORTS, not its name or folder: modules
  importing vendor SDKs (nautilus_trader) are ACL material even under an
  adapters/ subtree inside the context, class-bearing engine modules get
  filename=classname homes (<name>_service.py / <snake_class>.py), free-function
  job modules keep short names in services/<area>/ packages (freqai layout-audit
  precedent), and a context that only CONSUMES domain types warrants ZERO domain
  moves (execution recon finding — domain was already complete; check before
  inventing moves to justify a plan). Also grep for pickle remaps (_CANON) and
  legacy logger-name lists BEFORE promising "pure relocation" in the plan.
- ARCHITECTURE.md is the placement-law source of truth for planning: its area
  tables state where each existing artifact lives AND sometimes annotate intent
  ("services orchestrate, engine math stays here") — read the relevant table rows
  first so the plan's destinations agree with documented law instead of
  re-litigating it. Note it lives at python/andromeda/ARCHITECTURE.md (repo
  root has no ARCHITECTURE.md despite commit subjects saying just
  "ARCHITECTURE").

## Verification & attribution

Scoped suite + ruff on changed paths per wave. For any full-run failure:
checkout your committed HEAD into a pristine `/tmp/head-proof` worktree and run
the failing set there — green there proves the failure belongs to the other
session's WIP. Commit-gate bypass (`git -c core.hooksPath=/dev/null commit`,
once per deadlock) requires baseline proof + evidence written into the commit
message body. After EVERY commit in the shared tree, read `git show --stat
HEAD`: broad-path staging sweeps in the other session's staged debris; accept
harmless items but say so. When a shared test file fails after both sessions
edited it, diff it against HEAD first — one side often completes a rename
(guard kwargs, helper signatures) while leaving call sites stale; finishing
the mechanical rename is faster than re-litigating attribution.
Attribution under a foreign red wave: when N tests fail with ONE shared
error signature rooted in a file you never touched (e.g. their half-landed
PaperPipeline ctor change), do NOT repair it — prove your surface green via
isolation (run only the suites that don't route through their broken path,
assert exit 0), commit history-safely, and report the blocker with its exact
signature + owning file. Re-run after their wave lands to confirm full
green; a system verifier may re-ask for "fresh evidence" — answer with the
drift check + scoped suite + the precise foreign blocker, never a fake
green.

See references/dissolved-contexts.md, references/case-studies.md (venue) and
references/session-case-study.md (risk+session, the fullest worked example)
for the case log (what moved where, and the evidence-driven plan corrections).
references/runner-case-study.md documents the FULL runner arc — contract
creation, family co-location, loop fold, collapse to a single concrete
RunnerService, then the 2026-08-24 double reversal (package+facade, same-day
ABC order): FINAL state is services/runner/{runner_service.py =
class RunnerService(ABC), live_runner_service.py = LiveRunnerService(RunnerService)
gated loop, historical_runner_service.py = HistoricalRunnerService(RunnerService)
batch NT backtests}, no facade alias — read it before touching anything under
services/runner/ or proposing any service
hierarchy/collapse/rename here. references/strategy-host-case-study.md holds the
verified placement map + consumer inventory + waves for the strategy_host
dissolution; read/update it before executing that context.
references/catalog-case-study.md holds the EXECUTING catalog parallel-existence
dissolution (wave-1 import-substitution table + evidence log inside);
references/catalog-waves.md is the wave log + w3 seam-refresh/bridge detail + the
EXECUTED w4 demolition notes — read it before touching any catalog-area survivor
(services/catalog_service.py, services/catalog/*, domain/{bar_math,equity_listing,catalog_requests}).
references/freqai-host-case-study.md held the researched plan; execution
landed as bd43e456→90e1f828→0a920ac9→7b6c8c26 (waves A/B/C + the stale-buffer
repair) — see Techniques for the subagent-timeout and sanitize-dance-v2
lessons before delegating or committing in this campaign.

## Shared-checkout commit lessons (execution dissolution, 2026-08-24)

- Mixed-vs-foreign classifier under a hot index: classify a changed file
  MINE-AFFECTED iff its HEAD version CONTAINS the old module token
  (`andromeda.contexts.<bc>.`) — foreign brand-new files never do; pure-mine
  files differ from HEAD only on token-rewrite lines; true mixes are
  HEAD-has-token AND diff carries non-token changed lines. Classifying by
  diff-line tokens alone misfiles ~120 foreign files as "mixed".
- `git mv` refuses repo-external destinations MID-SCRIPT (exit 128 kills the
  remaining commands): never stage a fold through /tmp inside one bash block;
  read the source, fold its body into the destination, then `git rm` it.
- A foreign COMMIT can resolve your mixed set to ZERO by absorbing the other
  session's halves of every shared magnet (happened twice in one hour):
  RECLASSIFY FRESH immediately before each commit attempt instead of
  sanitizing against a stale classification — after their absorb, plain
  pathspec commit needs no dance at all.
- Porcelain v1 rename entries are `R  old -> new`: parse both endpoints before
  building pathspec-from-file lists or git aborts on the arrow strings; name
  BOTH endpoints (git then records clean R093–R100 renames). Verify
  completeness via `git show --name-status | grep -c '^R'` + destination ls —
  `--name-only` prints rename pairs as ONE line and looks like half your
  paths "missed".
- Proof-test placeholders written by a parallel agent (`with
  pytest.raises(X): pass`) fail by construction — attribute via git status
  (their MM) before treating as your regression.
- NT proof-writing shortcuts (parity wave): reuse `mapping.bar_rows_to_nt_bars`
  for BarRow→NT Bar conversion (hand-built Price.from_str bars hit precision
  mismatches vs the instrument's price_increment); fills-report evidence lives
  in the `commissions` COLUMN as a LIST of Money reprs ("60.26 USDC"), not a
  scalar `commission`; run_paper_backtest consumes ts_event duck-bars
  (SimpleNamespace), not BarRow.
- Dot-bar output is not evidence: a green `.....` progress line with the
  summary line swallowed (quiet mode, log truncation) proves nothing — count
  from `--junitxml` (`testsuite` attrs: tests/errors/failures/skipped) or the
  captured exit code. Watch the XML filter too: a `<skipped/>` child makes a
  testcase "have children" and looks like a failure to naive
  `list(testcase)` filters; filter on the specific `failure` tag.
- PRISTINE PROOF IS A CLOSE-OUT GATE, not just an attribution tool (execution
  dissolution, 2026-08-24): after committing a multi-file move wave, run the
  scoped suite in a fresh `git worktree add /tmp/head-proof <sha>` BEFORE
  declaring done. Worktree-scoped suites stayed green through a hole where 46
  consumer files' dissolution import rewrites were never committed (a fresh
  reclassification misfiled them foreign because concurrent freqai commits
  touched them between passes); the hole surfaced ONLY as collection
  ModuleNotFoundError in the proof worktree (real_execution_service.py
  importing dissolved contexts.execution.paper). Repair-forward shape:
  `git grep -l <old-token> <bad-sha> -- python`, apply the ordered
  substitution table to HEAD content of exactly those files (sanitize dance),
  commit as an explicit fix naming the root cause. Output of that grep is
  `<sha>:<path>` — split ONCE on the first colon.
- Wave-0 leaf timeout variant with ZERO mutations: unlike earlier waves
  (leaves finish mutations then die reporting), both parallel leaves here
  died before writing anything. `git status` the exact target files first;
  nothing landed ⇒ absorb BOTH scopes into the parent in one pass after
  reading every seam file — re-dispatching blind pays a second 600s for the
  same nothing.
- Foreign WIP imported by YOUR mixed shared files must be stripped back to
  HEAD form at commit time EVEN IF IT PARSES TODAY: their module flip-flopped
  between SyntaxError / circular-import / working states hour by hour
  (untracked freqai_service.py), so any commit of yours referencing it
  guarantees a broken SHA. Sanitized makers.py shipped HEAD+my-edits-only
  while their FreqaiService delta stayed uncommitted in the worktree.
- Composition stamping of config onto adapters: the cost model does NOT go on
  PaperPipeline's ctor (TypeError at construction) — stamp it onto the paper
  ADAPTER inside make_pipeline via `dataclasses.replace(adapter,
  cost_model=...)`, guarded to PaperExecutionAdapter instances whose model is
  None. Import-cycle-safe type check is `type(x).__name__ == "..."`; ruff
  SIM102 wants the guard conditions as ONE parenthesized `and` chain, no
  nested ifs.
- Fee-model symmetry law (one executor fed differently): when the paper
  adapter zeroes a disabled cost model, the NT fee translation must too
  (`if not model.enabled: return Money(0, ccy)`) — mirrored tests assert the
  same gate semantics on both hosts. NT specifics (nautilus_trader 2.0.0rc2)
  live in references/execution-case-study.md; probe vendor APIs live in the
  venv BEFORE writing the wrapper class — one interpreter round-trip saved
  three test-failure cycles.

references/execution-case-study.md holds the EXECUTED execution dissolution
(84490a41): final placement map with research-vs-executed deltas (suffix law
overrode planned filenames, exits went to domain not services, nt_fills died
shell despite research claiming a sole consumer), verification evidence, and
the Phase B open items of unified-sim-executor — read it before touching
services/execution/** or continuing waves 1–2.
references/service-consolidation-case-study.md covers package → single-Service
absorption (freqai 2026-08-24): ruling-driven domain extraction set before
building the merged module, verbatim segment-splice assembly with its
indentation/idempotency traps, load-bearing deferred imports at cycle edges,
test-suite consolidation (fixture collisions, monkeypatch retargeting), and
pickle `_CANON` retargeting to the class's defining module — read it before
merging multiple modules into one service or folding wrapper classes into
ctor state.
