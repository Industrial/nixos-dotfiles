# Context dissolution case studies

# Execution dissolution case study (2026-08-24)

## Pre-state

contexts/execution held ten modules: paper engine half (pipeline.py PaperPipeline,
exits.py level-1 exit math, exit_policy.py, paper.py PaperExecutionAdapter,
application/backtest.py run_paper_backtest) + NT-vendor bridge half
(adapters/nautilus/{strategy_adapter,nt_compose,nt_backtest}.py, nt_fills.py).
services/execution/ already existed with ExecutionService ABC + Synthetic/Real/Hyperliquid
axis kinds wrapping the engine. ~52 verified import sites incl. 5 patch strings
(paper_session_test x4, contexts/catalog/testing/memory_store.py:247).

## What landed (parallel session's shape)

- Engine half → services/execution/*_service.py: paper_pipeline_service.py,
  paper_execution_service.py, backtest_service.py — full filename=classname law adopted.
- Exit math promoted FURTHER than planned: domain/exit_rules.py (+ policy/test files) —
  ruling went more aggressive than the "defer taxonomy promotion" REC.
- NT bridge → acl/nautilus/{strategy_adapter,nt_compose,nt_backtest,hl_nt_capture}.py;
  nt_fills.py deleted outright rather than relocated.
- legacy_pickle._CANON gained contexts.execution.paper → services.execution.paper_execution_service:
  proof that PaperExecutionAdapter IS pickled somewhere — the planning session's grep-based
  "no remap needed" conclusion was WRONG; remaps must cover any class reachable from
  serialized session state, not just obviously-persisted models.

## Concurrent-execution collision (the defining event of this dissolution)

The planning session's wave-1 git mv failed with `bad source`: a parallel session had
staged-and-was-refining the entire dissolution between plan approval and wave dispatch.
Protocol that worked (now doctrine in core/id-workflow):

1. NEVER retry a move after `bad source` on freshly-verified paths. Re-check
   `git log --oneline -2` + `git status --porcelain` immediately.
2. Attribute: HEAD advance = committed work; staged moves + fresh unstaged edits on top =
   still mid-flight. Do not touch either.
3. Foreign staged COSMETIC hunks on your own surface (their isort/format sweep reordered
   imports in files you also need): pure-reorder diffs ride along as disclosed riders —
   unstaging risks corrupting their operation. Distinguish via
   `git diff --cached -- <path>`: reorder-only = cosmetic rider; semantic = escalate.
4. Convert your role to read-only verification of THEIR state: residual-import greps
   (zero contexts.execution imports), F821 over affected surface, scoped pytest battery,
   logger/patch-string spot checks. Attribute every failure before reporting:
   foreign file (catalog session's backfill_questdb F821) vs real defect vs scratch-env gap
   (bare .venv missing dependency_injector → composition/http/cli collection errors).
5. Annotate YOUR plan artifact with an Outcome annotation section: who executed it,
   deltas vs your placement table and the user's rulings, residual gaps for their closeout
   (here: ARCHITECTURE.md rows unrepointed, stale docstring phrase). Cancel wave todos as
   cancelled, not completed.

## Lessons

1. Placement tables are hypotheses until cut time; the executing session may validly go
   further (domain promotion) or differently (filename law) than the REC — record deltas,
   don't fight them post-hoc.
2. Pickle-remap completeness cannot be established by grep alone; when in doubt add the
   remap entry — it is inert if unneeded.
3. A dissolution executed by another agent is still verifiable independently: scope every
   check to the dissolved area and attribute the rest.
4. Scratch venvs (uv-created, bare) lack repo deps by design — collection failures there
   are environmental evidence gaps, never suite-red claims about the tree.

# Venue dissolution case study (2026-08-23, task tsk-mt5rlet5-sqsmtf)

## Fragmentation found (the pre-service shape)

Four venue-key normalizers with disagreeing alias sets:
instruments._normalize_venue (no us/equity/glbx), cost_model.normalize_venue_key
+ inline sets (had them), makers.venue_key (no aliases), multi_venue bare
strip().lower(). Unknown venues silently returned []/None while
UnknownVenueError sat nearly unused. Executor selection lived in composition
factories; dry_run_guard.assert_dry_run_blocks_live only forwarded to
guards.forbid_live_under_dry_run.

## What landed

- domain/venue_key.py — VenueKey frozen dataclass; normalize() raises
  UnknownVenueError on empty/unknown; CANONICAL_VENUES = hl, ibkr, cme, paper,
  synthetic; default_key(); is_known(). Aliases: ibkr←interactive_brokers/ib/
  us/equity; cme←markettas/glbx; hl←hyperliquid.
- services/venue_service.py — single class: registry seeded from
  CANONICAL_VENUES, kind_for/list_pairs/cost_model/executor_kind/guard,
  re-exports the three area errors; lazy imports for delegation.
- Deleted dry_run_guard.py + test; ft_17_75 proof aliases guards function.
- Singleton wiring: UniverseContainer → ApplicationContainer → make_api_app →
  ApiApp.venue_service, with §5-rule-4 identity test asserting ApiApp holds
  the same instance two resolutions return.
- Consumers onto service: pairlists_rpc (host field + kwarg), pair_ohlcv,
  catalog enqueue. HTTP edges catch (VenueError, UnknownVenueError) to keep
  degrade-to-config-pairlist; everything else raises.

## Lessons

1. Consumer audit found "synthetic" as a fifth real kind living in CLI
   _DOWNLOAD_VENUES, catalog _PROVIDER_NAMES, nautilus mapping, and test
   configs — sentinels relying on silent fallthrough must join the canonical
   set before flipping lenient→strict.
2. Registry surfaces expose registration order; a test asserting sorted keys
   was wrong, not the service.
3. Lenient-behavior tests break loudly post-promotion; fix at the adapter edge
   (explicit catch) rather than weakening the domain raise.
4. patch tool race with the parallel agent reported failure although landed;
   re-read + git diff before retrying.
5. Full suite mid-flight showed 20 failures all in the parallel agent's move;
   venue slice 166 green. Scope verification to your slice + record evidence.
