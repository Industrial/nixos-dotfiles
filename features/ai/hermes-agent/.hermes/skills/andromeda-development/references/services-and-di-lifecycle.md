# Services, DI & Lifecycle — python/andromeda (2026-08-23 pivot)

Supersedes the ports/adapters + Protocol-first guidance for *new* work.
Normative doc in-repo: `python/andromeda/ARCHITECTURE.md`. SERVICE.md and
SERVICE_GENERIC.md were deleted in this pivot.

## What the architecture now is

- Unit of organization = **service**: one class, one responsibility over a
  context/domain area, wired with DI, single source of truth for its area.
- Domain classes are NOT services: pure dataclass class-trees live in
  `domain/`; orchestration lives in `services/`.
- Variation areas get small **class trees**: abstract frozen-dataclass root
  carrying shared state + query surface + abstract `method_name()` classmethod
  (doubles as registry key / wire name). Kinds own kind-specific `resolve(...)`
  classmethods raising package errors with stable messages.

## Naming rules (from ARCHITECTURE.md §3)

1. ALL exceptions live in `error/<name>_error.py`, class `<Name>Error`.
   Never define exceptions inline in service/domain/adapter modules.
2. Services: one class per file, `services/<area>_service.py`,
   class `<Area>Service`. `services/__init__.py` re-exports services only.
3. Domain classes: one class per file, filename = snake_case of class.
   Module helpers sit beside their primary class.
4. Class spelling reads as it sounds: `Pairlist`, NOT `PairList`. Wire/config
   identifiers keep their external spelling (`method_name()` returns
   `"StaticPairList"`). Never let string literals force class renames.
5. Tests colocated, suffixed `_test.py`.

## Canonical case study: the pairlist area

Layout after absorbing the old `contexts/universe` package entirely:

```
domain/pairlist.py            Pairlist ABC (+ filter_whitelist helper)
domain/static_pairlist.py     StaticPairlist.resolve(cfg, resolver, ...)
domain/volume_pairlist.py     VolumePairlist.resolve(volumes, n, ...)
domain/pairlist_filters.py    age/price/spread/precision/delist pure filters
domain/pairlist_shuffle.py    shuffle + volatility/range-stability filters
error/pairlist_error.py       PairlistError
services/pairlist_service.py  register/available_methods/kind_for/create
```

Service contract: seeded registry in `__init__`; unknown method ->
`PairlistError`; argument-direction misuse -> `PairlistError` (e.g. volumes
passed to static create); domain errors propagate unchanged (RunConfigError,
InstrumentMapError) so callers keep existing contracts. New kinds = new
domain file + `svc.register(kind)`; nothing else changes.

## Lifecycle (ARCHITECTURE.md §5) — provider kind IS the policy

| Provider | Lifecycle | Use |
|---|---|---|
| Singleton | one instance per container graph (= app lifetime) | registry-backed services, caches, job stores (SessionState, PairLocks, PairlistService, PairlistEvalHost) |
| Factory | fresh per resolution | stateless per-call collaborators |
| Resource | managed setup/teardown | logging, interrupt, run-dir |

Wiring pattern (pairlist):

```python
UniverseContainer:
    pairlist_service = providers.Singleton(PairlistService)      # ONE per app
    allowed_pairs    = providers.Factory(make_allowed_pairs,
                         cfg=..., resolver=..., service=pairlist_service)
ApplicationContainer:
    pairlist_service = universe.pairlist_service                 # same object
    pairlist_host    = providers.Singleton(PairlistEvalHost,
                             pairlist_service=pairlist_service)  # stateful host too
```

Rules: consumers NEVER construct a service (factory params / injected
dataclass fields only); module-level global instances are banned — invisible
to tests, unreplaceable via `.override()`, fork registry state. Every
singleton wiring ships an identity test (`test_pairlist_service_
is_process_singleton` in composition/application_test.py asserts root,
universe, and host resolve the SAME object). Adapter dataclasses may keep
`field(default_factory=...)` so bare construction still works in unit tests;
the wired graph overrides it via the provider.

## Ops pitfalls learned while landing this

- **Commit-gate deadlock:** the prek pre-commit hook runs the FULL
  `andromeda:coverage` moon task (~minutes). It exceeds the ~110s foreground
  cap and detaches to background; if any pre-existing test fails, every retry
  fails identically and you get staged-but-uncommitted state forever. Escape
  hatch (repo-documented): verify the failing tests fail identically at HEAD
  in a throwaway `git worktree add /tmp/head-check HEAD`, run scoped pytest +
  ruff on your own files, then ONE bypass commit
  `git -c core.hooksPath=/dev/null commit ...` with the justification in the
  message. Do not loop on the normal gate.
- **Concurrent sessions share the index.** Another agent committed mid-task
  and left in-flight files; a blanket `git add -A` swept two foreign files
  into my commit attempt. Discipline: `git status --short` immediately before
  EVERY commit; stage explicit paths only; `git restore --staged <foreign>`
  anything not yours. Re-check HEAD before composing messages — it can move
  underneath you.
- **devenv shell swallows/mangles long output** and re-runs prek install each
  invocation (noisy). For clean summaries redirect inside the command to
  `/tmp/*.out` and tail/grep that file. ctx_shell archives: copy archive IDs
  exactly (a typo costs two wasted calls).
