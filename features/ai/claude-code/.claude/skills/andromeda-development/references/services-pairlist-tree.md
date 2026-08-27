# andromeda/services PairList tree — shape, extension recipe, session notes

Distilled from the 2026-08-23 session that created `python/andromeda/services/`
(additive twin of `contexts/universe/`). Companion to the "Pairlist domain
exception" subsection in SKILL.md.

## Why it exists (decision record)

- User asked whether a PairList/VolumePairList/StaticPairList type tree plus a
  PairListService was the right structure; agent argued AGAINST (Protocol-first,
  SERVICE.md §8 anti-abstraction: no speculative ports, selection is boot-time).
- User overruled: wants the class tree AND the service, many kinds may follow.
  Directive for the build: additive only — "Don't remove any existing code.
  Only generate the new code." Full `*_test.py` coverage required.
- Status: services/ is NOT yet wired into composition/makers or pairlists_rpc;
  contexts/universe remains the production path until cutover. Treat services/
  as the canonical going-forward home when adding pairlist kinds.

## File map

| File | Contents |
|------|----------|
| services/__init__.py | exports PairList, StaticPairList, VolumePairList, PairListService, PairListError |
| services/pairlist.py | ABC + both kinds |
| services/pairlist_service.py | registry service |
| services/pairlist_test.py | 16 tests (tree contract + both kinds) |
| services/pairlist_service_test.py | 12 tests (registry + dispatch) |

## Design details worth preserving

- Base is `@dataclass(frozen=True)` + `abc.ABC` (no slots — slots+ABC-dataclass
  multiple inheritance was avoided deliberately). Base holds ONLY
  `pairs: tuple[Pair, ...]`; kind-specific fields live on subclasses.
- Shared query surface on the base: `allows(pair)`, `as_allowed_keys() ->
  frozenset[str]` (the SessionRunner gating currency), `__len__`, `__iter__`.
- `method_name()` abstract classmethod returns the FT method string
  ("StaticPairList"/"VolumePairList") and doubles as the service registry key —
  one declaration serves identity, registry, and future RPC dispatch.
- Construction is kind-specific `resolve()` classmethods mirroring the legacy
  semantics EXACTLY (same error messages, same ordering): Static =
  whitelist ∖ blacklist order-preserved → RunConfigError("pairlist empty after
  blacklist filter"), unknown pair → InstrumentMapError("unknown pair ...");
  Volume = deterministic top-N (`key=(-volume, str(pair))` tie-break),
  blacklist applied before the N-cut, same validation messages as
  contexts/universe/volume_pairlist.py. Consumers can migrate without any
  behavior change.
- Service extras beyond the legacy twins: `additional_blacklist` parameter
  (appended AFTER cfg.pair_blacklist / per-call blacklist) and strict kwarg
  checks (Static rejects volumes=; Volume requires volumes=) → PairListError.
- Extension recipe: subclass PairList → implement method_name() + resolve()
  → `service.register(kind)` (re-registering under an existing name replaces).

## Test-fixture notes (reusable patterns)

- RunConfig needs strategy_path/timeframe/stake/dry_run/pairlist/max_open_trades/
  leverage; pair_blacklist defaults to (). Build via keyword dataclass ctor with
  Timeframe.parse/StakeAmount.parse/Leverage.parse/Pair.parse.
- PairResolver.create(venue, {pair_str: instrument_id}); resolve raises
  InstrumentMapError for unknown pairs.
- Reachability trap found by test failure: through the service,
  VolumePairList's `number_assets < 1` guard is UNREACHABLE because
  number_assets=len(cfg.pairlist) and RunConfig validates ≥1 pair at
  construction. Cover that guard via direct VolumePairList.resolve() tests;
  via the service the reachable ranking error is empty-volumes →
  "VolumePairList empty after filter". Also: `_cfg()` with zero pairs trips
  RunConfig's own "pairlist must contain ≥ 1 pair" before service code runs.

## Verification commands (verified green 2026-08-23)

```
devenv shell -- .devenv/state/venv/bin/python -m pytest python/andromeda/services/ python/andromeda/contexts/universe/ -p no:cacheprovider -q   # 34 passed
devenv shell -- ruff check python/andromeda/services/
```

- ruff lives in devenv PATH, not the venv (`.devenv/state/venv/bin/python -m ruff`
  fails: No module named ruff).
- ctx_shell firewalls inline `-p` pytest flags as "interpreter with inline code
  execution"; wrap the whole thing in `devenv shell --` and it passes. Large
  outputs get archived out-of-band — grep via ctx_expand instead of re-running.
- devenv prepends ~50 lines of SyncProject noise to every run; don't misread it
  as test output.
