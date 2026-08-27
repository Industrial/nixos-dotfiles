# Venue dissolution case study (2026-08-23, task tsk-mt5rlet5-sqsmtf)

## What the area looked like

Four divergent venue-key normalizers with DISAGREEING alias sets:
- `contexts/venue/instruments.py::_normalize_venue` (hl/hyperliquid, ibkr/…, cme/markettas)
- `contexts/venue/cost_model.py::normalize_venue_key` + inline alias sets (added us/equity/glbx)
- `composition/factories/makers.py::venue_key` (no aliases, defaulted paper)
- `contexts/session/multi_venue.py` bare strip().lower()

Plus: unknown venues silently returned `[]` pairs / `None` cost model while
`UnknownVenueError` existed nearly unused; executor selection lived in
composition factories; `dry_run_guard.assert_dry_run_blocks_live` was a pure
forwarding wrapper around `guards.forbid_live_under_dry_run`; HTTP hosts
imported `contexts.venue.instruments` directly.

## What landed

- `domain/venue_key.py`: frozen `VenueKey` dataclass, `normalize()` raising
  `UnknownVenueError` for empty/unknown, `CANONICAL_VENUES = ("hl", "ibkr",
  "cme", "paper", "synthetic")`, `default_key()`, `is_known()`. Alias map:
  hl←hyperliquid; ibkr←interactive_brokers,ib,us,equity; cme←markettas,glbx.
  `synthetic` was added mid-wave after a consumer audit found it in
  CLI `_DOWNLOAD_VENUES`, catalog `_PROVIDER_NAMES`, nautilus mapping, and
  test configs — sentinels that relied on silent fallthrough belong in the
  canonical set, not in per-site special cases.
- `services/venue_service.py`: one class, registry seeded from CANONICAL_VENUES,
  `kind_for` / `list_pairs` / `cost_model` / `executor_kind` / `guard`,
  re-exports UnknownVenueError + VenueError + VenueConfigError. Lazy imports
  for instruments/cost_model delegation (avoids import cycles).
- Deleted: `contexts/venue/dry_run_guard.py` (+ its test). ft_17_75 proof now
  imports `guards.forbid_live_under_dry_run as assert_dry_run_blocks_live`.
- Wiring: `providers.Singleton(VenueService)` in UniverseContainer, aliased on
  ApplicationContainer, injected through `make_api_app` → `ApiApp.venue_service`;
  identity test `test_venue_service_is_process_singleton_and_injected_into_api_app`
  proves two resolutions same object + ApiApp holds it (§5 rule 4).
- Consumers rewired: pairlists_rpc (`evaluate_static_whitelist` + PairlistEvalHost
  take optional `venue_service=`), pair_ohlcv `available_pairs_body`, catalog
  enqueue. Both HTTP edges catch `(VenueError, UnknownVenueError)` explicitly —
  degrade-to-config-pairlist policy preserved at adapter edge, raise elsewhere.

## Corrections hit during execution

- Registry-order vs sorted: service exposes registration order like
  PairlistService.available_methods(); don't assert sorted().
- Old lenient behavior tests break loudly once the domain raises: the HTTP
  fallback test (`venue="nope"` → config pairlist) needed the explicit
  `(VenueError, UnknownVenueError)` catch at the edge rather than weakening
  the domain.
- `patch` reported write-failure race with the parallel agent on makers.py but
  the edit HAD landed — always re-read + git diff before retrying.
- Full-suite run during execution showed 20 failures, all in the parallel
  agent's session/candle→services move (ForwardRunnerService NameError,
  paper_session relocations, cli session_service wiring); venue slice ran
  166 passed. Scoped verification is mandatory in this shared worktree.

## Service-hierarchy follow-up (2026-08-23, later session, user-ordered)

After two debate turns arguing FOR a flat dispatcher service, the user ruled:
"I still want the venue service as abstract class and the venues as
implementations … No more discussion." What landed:

- `services/venue/` package: `venue_service.py` = abc.ABC `VenueService`
  (registry / kind_for / normalize / executor_kind / default_key / guard
  shared; `list_pairs` + `cost_model` abstract) plus one class per file:
  `HlVenueService`, `IbkrVenueService`, `CmeVenueService`,
  `PaperVenueService`. Old flat `services/venue_service.py` deleted; its
  test git-mv'd into the package and rewritten through concrete subclasses
  (legacy tests constructing the bare ABC are exactly what the ruling kills).
- Selection: `UniverseContainer.venue_service = providers.Selector(
  providers.Callable(venue_key, raw_config), paper/synthetic →
  Singleton(PaperVenueService), hl/ibkr/cme → Singleton(<kind>) )`.
  Singletons because Factory branches break §5 identity tests. Keyed on
  venue_key deliberately: dry_run forces executor_kind→paper but universe/
  cost dispatch must follow the real venue — locked by a dedicated test.
- Subclass bodies delegate lazily to contexts/venue/{instruments,cost_model}
  (cycle-safe) with `cfg.setdefault("venue", "<own key>")` applied only when
  raw_config is a dict; non-dict input returns None to preserve legacy
  resolve_cost_model(None)→None. First draft used `raw_config or {}` and
  silently returned HlCostModel for None — the relocated legacy parity test
  caught it pre-commit. Run parity tests BEFORE rewriting them.
- PaperVenueService: empty universe without a loader, delegates when given
  one (synthetic catalogs list what they hold); cost model always None.
- Abstractness forced crutch repairs: pair_ohlcv.available_pairs_body,
  pairlists_rpc.evaluate_static_whitelist (both endpoint-default hl) and
  catalog enqueue.expand_universe_jobs fell back to bare `VenueService()`;
  repointed to `HlVenueService()` with a comment.
- Tests added: venue_kinds_test.py (abstractness frozenset, own-alias cost
  pinning, paper semantics, dry-run keeps real-venue dispatch, guard shared);
  application_test.py gained selector-selection via TEMP CONFIGS
  (create_container takes a path only — no overrides kwarg) and
  example-config Hl singleton assertions next to the identity test.
- ARCHITECTURE.md §1 venue table rows for contract + kinds, directory-map
  `venue/` line, and a composition note on venue_key-vs-executor_key.
- Verified amid the parallel SessionService dissolution: their rename broke
  tree-wide test setup (autouse conftest imports composition); scoped runs
  used QUESTDB_PG_URL=unused://, then application_test was retried once their
  rename settled — green. Final scope: 75 passed / 1 skipped, ruff clean,
  HEAD unmoved, nothing committed (foreign entries sat staged in the shared
  index; pathspec discipline held).
- `.maestro/` specs/contracts/evidence still cite services.venue_service —
  historical evidence, left untouched, excluded from leftover greps.
- Post-approval rename ("we don't do acronyms"): `HlVenueService` →
  `HyperliquidVenueService`; git mv `hl_venue_service.py` →
  `hyperliquid_venue_service.py`; scripted replace over 10 files / 28 hits
  including the contract-module docstring and the ARCHITECTURE.md table row.
  Selector arm and operator config values stay `hl` — wire names untouched.
  Re-verified after: scoped pytest 75 passed / 1 skipped, ruff clean,
  old-name grep empty.
- Same-ruling completion ("do the same for the other venues … provide
  `*_test.py` files for each"): `CmeVenueService` →
  `ChicagoMercantileExchangeVenueService`, `IbkrVenueService` →
  `InternationalBrokersVenueService` (names mirror the adapter classes in
  contexts/venue/adapters/driven), modules git-mv'd to full snake_case, plus
  colocated `<kind>_venue_service_test.py` for all four implementations
  (contract conformance, own-key cost pinning, None-config parity,
  alias-normalization via loaders, paper semantics, guard). Lengthening names
  pushed several import blocks past ruff's 100 cols → E501/I001 mechanical
  fallout; fixed by wrapping the imports. Two real catches: (1) test loader
  payloads must be FT pairs (`"6J/USD"`, not `"6J"`) or instruments'
  `_dedupe_sorted` silently filters them out — legacy behavior, payload bug;
  (2) a batch string-replace mis-indented a call inside one new test and
  duplicated an assert line in another — F841/NameError signature, fixed by
  reading back exact regions instead of re-replacing blind. Final state:
  package green across services/venue + composition + HTTP + enqueue scopes,
  ruff clean, still uncommitted with foreign staged entries present.

## Second deletion wave: dispatch machinery superseded by the kinds (2026-08-23, same day)

User: "We still have a lot of code in contexts/venue. How much can now be
replaced by services/venue? Please do so." Importer audit showed the service
hierarchy had become the only production caller of three context modules, so
they were deleted outright:

- `instruments.py` (+ test): string-keyed `list_venue_pairs` → concrete base
  `VenueService.list_pairs` (loader path, `_dedupe_sorted` FT filter, hl→USDC
  stake default, `extra` passthrough for non-vendor keys) + a tiny
  `_adapter_pairs` hook per kind returning None for keys without an exchange.
- `cost_model.py` (+ test): `resolve_cost_model` if-chain and its lazy
  imports died; each vendor kind binds its concrete model directly
  (`HlCostModel.from_raw(self._resolve_cost_block(cfg, "hl_costs"), ...)`)
  through ONE shared base helper preserving the named-key → `afml.costs`
  fallback. Polymorphism replaces the switch.
- `guards.py` (+ test): invariant became
  `VenueService.forbid_live_under_dry_run` staticmethod (kept the instance
  `guard()` wrapper); 4 driven venue files, `hl/orders.py`, and proofs
  ft_17_45 / ft_17_75 rewired (the alias-import proof needed the assignment
  moved BELOW its import block to satisfy isort).
- `CostModel` ABC relocated to `domain/cost_model.py` (pure abc/Any) and added
  to `_DISSOLVED_DOMAIN_FILES`; concrete cost models stayed beside their
  adapters (vendor-coupled, heavily consumed by execution internals).
  Process slip worth remembering: the test file was written but the module
  itself initially wasn't — tree-wide ModuleNotFoundError at collection.
- Left deliberately: `contexts/venue/adapters/driven/<venue>/` and
  `venue_executor.py` (type-only Protocol in the parallel session's active
  execution seam).
- Straggler sweep found four refs my earlier "test-bucket" grep had buried:
  cme/instruments_test dispatch case rewritten against the kind;
  providers/cme_test's permanently-skipped stub test deleted with its import;
  guards_test rewritten against the staticmethod; pair_ohlcv_test's
  monkeypatch target was ALREADY dead pre-refactor (unknown venues raise in
  key normalization before any dispatch function runs) — replaced by a
  comment asserting the degrade-to-config-pairlist behavior directly.
  Lesson: audit the test-reference bucket too, not just production imports.
- One regression introduced AND caught in the same pass: rewriting
  `resolve_cme_costs` to delegate through the CME kind made it return
  CmeCostModel for `{"venue": "hl"}` configs (its own costs_test caught it).
  Fix: pre-check venue (`is_known` → normalize → compare "cme") BEFORE
  delegating. Also rejected mid-fix: an `__import__` hack for a lazy import —
  wrote the clean two-step lookup instead.
- Final verification: services/venue + domain/cost_model_test +
  contexts/venue/ (adapters incl. rewired tests) + composition + HTTP +
  enqueue + layout gates + both dry-run proofs + transitive nautilus
  consumers (nt_compose/mapping exercise resolve_cme_costs & HlCostModel)
  all exit 0; ruff clean on every touched path. ARCHITECTURE.md table gained
  the CostModel row and a "no string-keyed dispatch module" note. Still
  uncommitted; shared-index caution stands.
