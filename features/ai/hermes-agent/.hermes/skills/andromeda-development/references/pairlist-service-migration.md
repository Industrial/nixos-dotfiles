# PairlistService Migration — session detail (2026-08-24)

## What replaced what
| Old | New |
|---|---|
| contexts/universe/pairlist.py (StaticPairList, filter_whitelist) | domain/pairlist.py (Pairlist ABC + filter_whitelist) + domain/static_pairlist.py (StaticPairlist) |
| contexts/universe/volume_pairlist.py (VolumePairList) | domain/volume_pairlist.py (VolumePairlist) |
| — | services/pairlist_service.py (PairlistService, sole class) |
| — | error/pairlist_error.py (PairlistError) |
| SERVICE.md + SERVICE_GENERIC.md | ARCHITECTURE.md (clean-generation rewrite; never cite the old docs) |

## The five structural corrections (user-directed)
1. ALL exceptions live in `andromeda/error/<name>_error.py` — never defined inline in a service/domain/adapter module.
2. One class per file under `services/`: `pairlist_service.py` holds ONLY PairlistService.
3. Class naming is `Pairlist`, NOT `PairList`. Wire/config names keep FT spelling: `method_name()` returns `"StaticPairList"` / `"VolumePairList"` so operator configs stay stable. Never let a string literal force a class rename or vice versa.
4. One file per class: `domain/pairlist.py`, `domain/static_pairlist.py`, `domain/volume_pairlist.py`.
5. The kinds are NOT services → they live in `domain/`, not `services/`.

## Service contract
- Registry: `register(kind)` / `available_methods()` / `kind_for(method)`; seeded with Static+Volume in `__init__`.
- Dispatch: `create(cfg, *, resolver, method="StaticPairList", volumes=None, additional_blacklist=())` — static rejects a passed `volumes` kwarg; volume derives `number_assets=len(cfg.pairlist)` and requires volumes; unknown method → PairlistError; kind-level RunConfigError/InstrumentMapError propagate UNCHANGED so callers keep their contracts.
- Extension recipe: subclass Pairlist, implement `method_name()` + a kind-specific `resolve(...)`, then `svc.register(kind)` — no other code changes.
- Singleton wiring: UniverseContainer owns `providers.Singleton(PairlistService)`; `make_allowed_pairs(cfg, resolver, service=...)` and `PairlistEvalHost(pairlist_service=...)` (default_factory keeps bare test construction alive) share the root's instance. No module-level service globals. Identity proof: `container.pairlist_service() is container.universe.pairlist_service() is container.pairlist_host().pairlist_service`.

## Consumers rewired
- composition/factories/makers.py::make_allowed_pairs → `service.create(cfg, resolver=...).as_allowed_keys()`
- adapters/driving/http/pairlists_rpc.py → `kind_for()` is the method-name authority (registering a new kind automatically makes the RPC aware); `filter_whitelist` from domain
- contexts/execution/application/backtest.py → `filter_whitelist` from domain
- proofs ft_17_03 / ft_17_36 / ft_17_37 migrated; old modules + tests git rm'd (git recorded volume_pairlist as a rename)

## Gotchas hit
- `from andromeda.domain.pairlist import StaticPairlist` FAILS — each class owns its file; import from domain/static_pairlist.py (caused a proofs collection error until fixed).
- Through the service, VolumePairlist's `number_assets < 1` guard is unreachable (derived from validated non-empty cfg.pairlist); that branch stays covered via direct `.resolve()` tests.
- An empty-pairs `_cfg()` fixture trips RunConfig's own "pairlist must contain ≥ 1 pair" BEFORE the service runs — fixtures need ≥1 pair.
- Container-body ordering: a provider line can only reference providers declared ABOVE it in the DeclarativeContainer class body (NameError at import otherwise).

## Verification
devenv shell -- .devenv/state/venv/bin/python -m pytest python/andromeda/domain/pairlist_test.py python/andromeda/services/pairlist_service_test.py python/andromeda/composition/ python/andromeda/adapters/driving/http/pairlists_rpc_test.py -q
