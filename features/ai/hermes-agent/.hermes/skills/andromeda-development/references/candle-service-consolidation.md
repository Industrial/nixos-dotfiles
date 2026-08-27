# Candle area consolidation onto CandleService (2026-08-23)

Third application of the context→service consolidation pattern (pairlist →
risk → candle). Commit 0ae67548. Plan artifact:
`.maestro/plans/pln-andromeda-candle-service-consolidation.plan.md`.

## Target-selection evidence (what made candle "next")

An area ready for consolidation shows one or more of these signatures —
check them BEFORE planning, they justify the whole task:

1. **Orphaned proto-registry cluster**: a registry-like class
   (`CandleRegistry`) with ZERO production constructors — only tests build
   it — injected into consumer classes (`DataProviderProxy`,
   `NautilusDataProvider`) that themselves have zero production
   constructors. Dead wiring shaped like the future design.
2. **Scattered construction sites with divergent knobs**: N production
   `CandleStore(...)` sites each hardcoding different warmup policy
   (session train-window derivation vs hardcoded `startup=2` paper store
   vs `startup=1` RPC scratch stores).
3. **Hand-rolled re-implementation**: `ForwardSessionService` kept a private
   `stores: dict` + lazy `_store_for()` — exactly what the registry offers,
   forked per instance (the classic pre-PairlistService disease).

Exclusions to state up front: areas owned by parallel agents (RiskService),
transport-level buffers that legitimately stay local (venue bars adapters),
request-scoped scratch stores in driving adapters (documented exceptions).

## Dependency-direction constraint (the new problem this round solved)

ARCHITECTURE fixes direction `services → contexts`, so a CONTEXT class may
never receive a service typed parameter. Two composable patterns solved it:

### Pattern A — injected callable factory

Context dataclass takes `store_factory: Callable[[Pair], CandleStore]`;
composition binds it to the singleton method:

```python
# composition/factories/makers.py (may import services)
def make_forward_session(..., candles: CandleService, ...):
    return ForwardSessionService(..., store_factory=candles.get_or_create)
```

Container threading: owning container declares
`candle_service = providers.Singleton(make_candle_service, cfg=run_config)`;
consuming containers declare `candle_service = providers.Dependency()` and
the root passes `catalog.candle_service` in. Do NOT thread a raw lambda
through DI — pass the service to the maker, bind the bound-method there.

### Pattern B — Protocol port owned by the context

Read-side consumers take a narrow port declared under
`contexts/candle/application/ports/candle_source.py`
(`timeframe`, `pairs`, `get(pair)`); `CandleService` satisfies it
structurally. Contexts import the port, never services.

### Test conformance gotcha

A non-`@runtime_checkable` Protocol cannot be used with `isinstance()`
(TypeError at runtime). Assert conformance by ANNOTATION instead:
`svc: CandleSource = make_service()` — static check, runs green.

## Wave structure that worked

- Wave 0 baseline: full suite + ruff snapshot BEFORE editing; record
  pre-existing reds with test IDs. With a parallel agent active, re-run
  `git log` immediately before committing — baseline moves under you.
- Wave 1 introduce+repoint: service + colocated tests (validation errors
  asserted by type AND message fragment), maker + Singleton + identity test
  (`test_candle_service_is_process_singleton` mirroring the pairlist one),
  repoint every consumer, fix all affected test constructors.
- Wave 2 consolidate construction: remaining sites join the singleton;
  delete superseded helpers (`runner_core.make_candle_store`);
  hygiene-only touch-ups in scratch sites (drop redundant re-sets).
- Wave 3 remove: delete absorbed modules (`registry.py`, `warmup.py`,
  `store_from_bars`) AFTER grep proves no dangling imports; PORT proof-test
  hypotheses onto the surviving surface rather than deleting them (proof
  17.06 H1 moved from `WarmupGate.from_store` assertions to
  `CandleStore.ready`/`ensure_ready`). Docs truth: ARCHITECTURE.md table +
  directory-map rows + `services/__init__.py` export in the same commit.

## Verification discipline under devenv + concurrent agents

- devenv workspace-sync noise swallows pytest tails: redirect INSIDE the
  command to a file and read it back — with a UNIQUE name per run
  (`OUT=/tmp/gate_$$_.txt`); a parallel agent overwrote a shared
  `/tmp/w1gate.txt` mid-session and nearly caused a false verdict.
- Ruff version skew: the nix-store ruff (0.15.9) reports ~266 findings in
  python/andromeda that the pinned prek ruff does not. Compare findings on
  your touched files against `git show HEAD:<file>` copies before fixing;
  leave pre-existing classes alone.
- Scoped gate green = exit criterion for each wave; full-suite comparison
  against the Wave-0 baseline only at the end (collection errors from the
  other agent's syntax-broken WIP files are excluded via
  `--ignore=<their test file>` and reported as foreign).

## Concurrent-agent commit race (what actually happened)

While waves ran, the parallel agent (a) landed 4 commits moving HEAD
twice, (b) STAGED several of this agent's shared-file hunks
(`services/__init__.py`, two containers, `application_test.py`) together
with its own WIP, then (c) swept those staged hunks into ITS commit.
Handling that worked:

1. Before committing, classify every uncommitted hunk in shared files
   (`git diff <shared>`) as mine/foreign; verify staged-vs-HEAD deltas on
   shared paths are purely mine (`git diff --cached --stat -- <paths>`).
2. When the other agent's commit lands containing my hunks, VERIFY the
   swept content is equivalent (`git show HEAD:<file> | grep` for my lines)
   and shrink my remaining path list accordingly.
3. Commit ONLY explicit paths via a PARTIAL commit:
   `git commit -m "<msg>" -- <path>...` — takes working-tree content of
   just those paths and ignores foreign staged entries. Note `-m` must
   precede `--`; reversed order makes git parse the message as pathspecs.
4. Never `git add -A` in a shared tree; never stage the other agent's
   untracked WIP even accidentally via directory adds.

## Files touched (shape reference)

New: `services/candle_service.py` (+test), 
`contexts/candle/application/ports/candle_source.py`.
Rewired: makers (`make_candle_service`, `make_paper_store(cfg, service)`,
`make_forward_session(..., candles=...)`), catalog/session containers,
application_container threading, forward_session (dict internals deleted,
`store_factory` field), both data-provider proxies (port-typed).
Removed: `contexts/candle/{registry,warmup}*.py`, `nt_feed.store_from_bars`
(test folded into `feed_bars` coverage), `runner_core.make_candle_store`,
dead `composition/containers/runner_container.py` (zero references).
Docs: ARCHITECTURE.md candle-area concern table + §2 map row + §5
singleton exemplar mention; net +372/−239 across 26 files.
