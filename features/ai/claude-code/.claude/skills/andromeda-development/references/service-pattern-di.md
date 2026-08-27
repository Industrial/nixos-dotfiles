# Service Pattern: Ports, Adapters & DI — Session Knowledge Bank

Distilled from the 2026-08-23 architecture review that produced
`python/andromeda/SERVICE.md` (the repo doc is normative; this file preserves
the reasoning + verified evidence if the repo doc moves or gets questioned).

## The question and the verdict

User asked whether modeling the software as abstract classes + concrete
implementations with injected dependencies is a good idea. Verdict delivered:
YES to the architecture (dependency inversion at variation points,
constructor injection, single composition root), AMENDED mechanism — in
Python the abstraction should be a structural `typing.Protocol`, not an ABC.
The codebase already proves this works at scale.

## Verified evidence base (2026-08-23)

- Port census via grep: `class X(Protocol)` = 17 production files (+5 in test
  doubles = 22); `abc.ABC` subclasses = exactly 2 (`Venue`,
  `CostModel`). Count command:
  `grep -rE "class [A-Z][A-Za-z]+\((Protocol)" python/andromeda --include="*.py" | grep -v _test | wc -l`
- Ports found: BarFeed, QuestDbConnection, CatalogStore, ObjectStore,
  FeaturePipeline, ModelStore, TensorBackend, InstrumentDirectory, BookSource,
  EventTimeClock, TradeFlowSource, Runner (contexts/session/runner_protocol.py),
  VenueExecutor (contexts/venue/venue_executor.py), SessionControl,
  RateLimiter, ArchiveObjectStore, HyperOptLoss.
- Adapter style: `PaperExecutionAdapter` = `@dataclass(slots=True)`, no
  inheritance, docstring says "Implements VenueExecutor", exposes BOTH the
  port method (`submit`) and extra concrete methods (`fill`, `fills = fill`
  class alias).
- Composition: ApplicationContainer (DeclarativeContainer) nests
  Execution/Catalog/Session/TradeBook/Universe/Risk containers;
  `providers.Selector(providers.Callable(executor_key, raw_config),
  paper=..., hl=..., ibkr=..., cme=...)`; Resource providers yield/finally for
  logging/interrupt/run-dir; Singleton only for SessionState; nested containers
  use providers.Dependency().
- Test idiom (composition/application_test.py): `_SpyVenue` bare class +
  `with container.run_config.override(fake):` — provider overrides replace
  monkeypatching entirely. Container L0 tests assert wiring shape
  (`issubclass(ApplicationContainer, DeclarativeContainer)`).

## Key arguments for Protocol over ABC (used in SERVICE.md §1)

1. No adapter→port import coupling; adapter modules stay free-standing.
2. Third-party objects conform without shims — critical here because
   NautilusTrader types and freqtrade strategy objects must slot into ports.
3. ABC buys nothing at runtime in Python; isinstance gates on abstract types
   are ceremony. runtime_checkable gives presence-only checks where wanted.
4. Structural conformance is enforced by type checkers anyway.

## When NOT to abstract (SERVICE.md §8 guardrails — the failure mode)

- Two implementations or it didn't happen: no speculative ports.
- Don't mirror vendor SDK surfaces as ports; model OUR roles
  (CatalogStore not QuestDbWrapper).
- No pass-through interfaces (port re-exposing delegate 1:1).
- Config is not a hidden dependency — pass RunConfig values explicitly.
- Pure functions (afml/, indicators) take no container and no ports.
- Rule of thumb: #ports tracks #external boundaries (venues, storage, feeds,
  time, process control), not #classes.

## Deviations ledger (SERVICE.md §9)

| Site | Status |
|------|--------|
| contexts/execution/application/ports/driven/venue.py::Venue(abc.ABC) | Legacy debt; do not extend; target VenueExecutor instead; remove when last consumer drops it |
| contexts/venue/cost_model.py::CostModel(abc.ABC) | Tolerated (near template-method); re-evaluate on next touch |

New ABCs require a docstring justification per SERVICE.md §4.

## Repo-doc quirks noticed during the review

- README.md links CLI.md, TESTING.md, BOUNDED_CONTEXTS.md, GLOSSARY.md etc.,
  but ONLY README.md and one VENDOR.md exist under python/andromeda/ — most
  linked docs are missing (IMPLEMENTATION.md confirmed absent). SERVICE.md was
  written to link only README.md so it doesn't inherit dead links. If asked to
  fix the doc tree, the links are aspirational, not deleted files.
- application.py is a compat re-export shim; real graph lives in
  application_container.py + create_container.py.
