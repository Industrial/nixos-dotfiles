# Catalog dissolution wave log (contexts/catalog → services/domain/acl)

DISSOLVED 2026-08-24 — was the last bounded context in the repo; `contexts/` no longer exists. Spec: `.maestro/specs/catalog-dissolution-catalogservice.md`.

## Wave log

| Wave | Commit | Content |
|---|---|---|
| w1 | 7f2b2ee2 | CatalogService + questdb ACL created beside the untouched context |
| w2 | 575a632e | composition/container cutover onto CatalogService |
| w3 | d763cb5c (+repair 01db17eb) | consumer cutover COMPLETE: zero `contexts.catalog` refs outside the context; NT parquet test family reunited with relocated writers; driving-layer seams refreshed |
| w4 | EXECUTED uncommitted (2026-08-24 session) | `git rm -r contexts/catalog` incl. contexts/__init__ (package gone); conftest bridge removed (`stub_legacy_store_factory` helper + both call sites); tombstone `test_catalog_context_dissolved` asserts whole contexts/ tree absent; purity gate += domain/bar_math, domain/equity_listing; stale success-criteria asserts (contexts/execution+contexts/catalog) dropped; F401 residue cleaned in services/catalog/downloader{,_test},micro_downloader |

Other sessions landed mid-w3 (adapt, don't fight): freqai package move 73bda3d7, FreqAIHostService rename 641c81fa, execution dissolution 84490a41.

## New homes reached in w3

- Writers/tests: `adapters/driven/acl/nautilus/{nt_book,nt_ctx,nt_trades}.py` + their `*_test.py`
- Domain math: `domain/bar_math.py`, `domain/equity_listing.py`
- Symbology: `adapters/driven/acl/ibkr/symbology.py`
- Providers: `adapters/driven/acl/providers/<vendor>/`
- Import daemon: `adapters/driven/import_daemon/`

## Wave-3 production repairs (found by ported tests)

1. `paper_session._sync_hl_micro_or_pending` must call the facade verb `CatalogService.require_from_env().sync_micro_from_hl(...)` — bypassing via the adapter free-function makes facade-level mocks miss silently.
2. `_paper_run` reads `forward.artifacts_root` (runner gained it on `configure_loop`). `forward.catalog.root` no longer exists; the AttributeError was eaten by the best-effort try → run dirs silently vanished (6 red tests, one root cause).
3. `app.run_download_data` dropped the deleted `data_catalog` provider; downloaders resolve stores internally (`cat=None`).
4. Parquet-retirement rulings executed loudly: `run_import_ft_data` and `_cmd_catalog_backfill_questdb` raise `BotControlError` → JSON error, exit 1 (the backfill target module never moved anyway).

## Test-seam refresh pattern

Dead names ported tests still patch: `require_questdb_store`, module-level `load_instrument_and_bars`, `DataCatalog`, `data_catalog`, `import_ft_ohlcv`.

- Repoint to `CatalogService.require_from_env` / `CatalogService.load_instrument_and_bars` via **string-target** setattr (`monkeypatch.setattr("andromeda.services.catalog_service.CatalogService...", ...)`).
- Configure ONE service mock: `svc.load_instrument_and_bars.return_value = (inst, bars)` and stub only `require_from_env`. Double-patching class method + bare MagicMock explodes at `inst, bars = svc.load(...)` with 'not enough values to unpack'.
- Object-form setattr with dotted names (`setattr(app, "CatalogService.require_from_env", ...)`) is a literal attribute lookup → AttributeError.
- CLI fake containers need provider-shaped attrs: callable AND `.override()` (run_paper/run_backtest override then resolve `catalog_root`); serve fakes need `raw_config` callable + `session.venue.override`.
- Interrupted lineages leave duplicate husk tests (empty body / `assert True` placeholders) — replace with real behavior coverage, don't port them forward.

## conftest bridge (parallel existence)

`stub_legacy_store_factory(monkeypatch, store)` in `adapters/driven/acl/questdb/testing/memory_store.py` stubs the LEGACY factory seam (`contexts.catalog.adapters.questdb.catalog_store.QuestDbCatalogStore.require_from_env`) to the same store that `patch_questdb_factory` puts behind `CatalogService.require_from_env`. Called from BOTH `questdb_memory` and the autouse `_questdb_memory_unless_live` tail. Exemptions: `catalog_factory_test.py` (whole file), `catalog_store_test.py::test_catalog_store_from_env` (pins real env contract). Helpers live in the testing module — functions defined at conftest top level get collected as fixtures ('Fixture called directly').

## Verification protocol

- Batteries: `cd python && env -u QUESTDB_PG_URL ../.devenv/state/venv/bin/python -m pytest <paths> -q`. NEVER `QUESTDB_PG_URL=unused://` for gates — conftest stubs only when the var is unset, so unused:// half-state produces psycopg2 'invalid dsn' + spurious CatalogError noise.
- Gates: exit code + FAILED lines from the full log; scoped ruff F821+E501; tree-wide F821 sweep after import rewrites; py_compile anything touched by string-replace reflow.

## Wave-4 checklist → EXECUTED (2026-08-24, uncommitted at execution time)

1. Quiet-tree gate first (foreign sessions actively landing). ✔ HEAD moved 3× mid-wave.
2. Delete `contexts/catalog/**` + `contexts/__init__.py` (package gone); tombstone asserts the WHOLE contexts/ tree absent (last-context form). Stray fixture `micro/BTC_USDC_1h.parquet` rode along; staged nt_* deletions from w3 absorbed.
3. Bridge removal ATOMIC: `stub_legacy_store_factory` deleted from the NEW acl testing module + both call sites (`questdb_memory`, autouse tail) dropped from conftest.py — new-world seam was already `_QUESTDB_STORE_PATCH_TARGETS = ("andromeda.services.catalog_service",)`.
4. Purity gate += `domain/bar_math.py`, `domain/equity_listing.py`. ✔
5. ARCHITECTURE.md needed NO row changes (no catalog table rows existed); success-criteria checklist lost its `contexts/execution`+`contexts/catalog` existence asserts — the whole test had been silently SKIPPING since BOUNDED_CONTEXTS.md vanished, hiding the stale positive asserts.
6. Residue cleaned per shell-death law: F401s in downloader{,_test}/micro_downloader (dead imports left by the w3 seam refresh); dead alias `sync_catalog_micro_from_hl = sync_micro_from_hl` killed in acl/hl/capture/hl_micro_sync.py, its one consumer (partial_failure_test.py:173) repointed to `sync_micro_from_hl`.

Verification evidence: scoped env-unset batteries green (layout gate incl. new tombstone, CatalogService, services/catalog, questdb ACL, import_daemon, domain bar_math/equity_listing); paper_session seams verified in isolation; ruff F821/E501/F401 clean on all touched files; symbol-level leftover grep empty outside provenance docstrings in new homes. Full-tree battery remained blocked ONLY by the foreign freqai_service↔materialize import cycle (untracked WIP of the parallel consolidation session): --continue-on-collection-errors showed 17 FAILED + ~30 collection ERRORs sharing ONE ImportError signature with zero contexts.catalog frames — attributed, not repaired, re-probed cheaply before each verification round.

Symbol-census method (reusable): AST-parse public top-level symbols of every non-test context module, index definitions across the rest of the tree, classify ALIVE (with homes) vs RETIRED — proves symbol-level dead-ness beyond module greps and doubles as the post-dissolution functionality/consumers inventory users ask for. Coverage parity via patch-string search found equity_importer's only tests living in app_main_test.py seam patches.
