# Create-Only Parallel Package Extraction (catalog → new ACL/provider/import-daemon packages)

Session handoff + technique notes for the task class: "create NEW packages inside
python/andromeda as faithful copies of existing contexts/catalog trees, with import
rewrites, under a strict CREATE-ONLY constraint (never modify, move, or delete ANY
existing file anywhere in the repo)".

## Task contract (2026-08-23 session, UNFINISHED)

Ordered: (1) NEW questdb ACL package, (2) NEW provider packages, (3) NEW
import-daemon package — copies of `python/andromeda/contexts/catalog/adapters/
{questdb,providers,download}` + `contexts/catalog/testing/`. Hard rule: zero
mutations outside the new trees. Final destination dirs were NOT yet confirmed
with the user; evidence points to `adapters/driven/acl/questdb/` for the questdb
tree (mirrors existing `adapters/driven/acl/{nautilus,hl,cme,ibkr}`), but ASK
before writing.

## Complete source inventory (61 files, verified via find)

- `adapters/questdb/` — 27: `__init__.py`, `catalog_store.py`(+test),
  `client.py`(+test), `mappers.py`(+test), `questdb_integration_test.py`,
  `repositories.py`(+test, +repositories_load_test.py), `rows_test.py`,
  `rows/` (`__init__.py`, `schema.py`, `md_{bar,funding,index,l2,mark,micro,oi,trade}.py`)
- `adapters/providers/` — 17: `__init__.py`, `cme.py`(+test),
  `crypto_spartan.py`(+test), `hyperliquid.py`(+test),
  `markettas_datasource.py`(+test), `ohlcv_1m.py`(+test), `stooq.py`(+test),
  `synthetic.py`(+test), `synthetic_micro.py`(+test)
- `adapters/download/` — 15: `__init__.py`, `daemon.py`(+test), `enqueue.py`(+test),
  `import_job.py`, `job_key.py`, `job_store.py`(+test), `logging_setup.py`(+test),
  `progress.py`(+test), `worker.py`(+test)
- `testing/` — 2: `__init__.py`, `memory_store.py`

READ STATUS: all files fully read EXCEPT these five download tests:
`daemon_test.py`, `enqueue_test.py`, `job_store_test.py`, `logging_setup_test.py`,
`progress_test.py`. Next session: read those five FIRST (batch 2-3 per call),
then start writing immediately.

## Rewrite surface: imports are NOT the only carriers of old paths

String literals embed module paths too. Found in this source set:

| Kind | Example | Action |
|---|---|---|
| monkeypatch-by-string | `client_test.py`: `setattr("andromeda.contexts.catalog.adapters.questdb.client.psycopg2.connect", ...)`; `hyperliquid_test.py` patches `"...providers.hyperliquid._post_info"` ×8; `worker_test.py` patches `"...download.worker.{require_questdb_store,load_instrument_and_bars}"` | rewrite string to new module path |
| importlib-by-string | `synthetic_test.py` / `synthetic_micro_test.py`: `importlib.import_module("<old path>")` | rewrite |
| logger names | every module's `logging.getLogger("andromeda.contexts....")`; `logging_setup._IMPORT_LOG_PREFIXES` tuple | rewrite self-referential entries; keep external prefixes |
| patch-target tuples | `testing/memory_store.py::_QUESTDB_STORE_PATCH_TARGETS` (20 old-world module strings) | see decision D3 |
| relative-depth anchors | `crypto_spartan_test/ohlcv_1m_test/stooq_test` use `parents[4]`, `cme_test` uses `parents[5]` for repo/test fixtures | RECOMPUTE after final destination depth is known |
| marker strings | `questdb_integration_test.py`: `pytest.mark.questdb` | marker exists in pyproject; keep |

## Out-of-scope sibling dependencies (decision D1: KEEP old-world imports)

These are imported by the copies but were NOT ordered copied. Keeping their
old-world imports preserves behavior AND monkeypatchability (tests patch module
attributes, which requires module-level imports — do NOT convert to
function-local imports in the copies):

- `contexts/catalog/download.py` → `BarsDownloadRequest` (hyperliquid.py,
  cme.py, synthetic.py, daemon.py, worker.py + tests)
- `contexts/catalog/equity_raw.py` → `SOURCE_*`, `is_complete`,
  `mark_complete`, `source_root` (crypto_spartan, ohlcv_1m, stooq + tests)
- `contexts/catalog/resample.py` → `resample_bars` (function-local in cme.py — may stay local)
- `contexts/catalog/adapters/parquet/catalog.py` → `DataCatalog` (worker.py, cme_test)
- `contexts/catalog/application/catalog_factory.py` → `require_questdb_store` (worker.py)
- `contexts/catalog/application/catalog_loader.py` → `load_instrument_and_bars` (worker.py)

Already NEW-WORLD (no rewrite needed): mappers.py uses
`adapters.driven.acl.nautilus.{book_map,mapping}`; hyperliquid.py uses
`adapters.driven.acl.hl.{rate_limit,s3_archive}`; cme.py uses
`adapters.driven.acl.cme.instruments`; worker.py function-locally uses
`acl.hl.s3_market_data` + `acl.hl.node_fills`; enqueue.py uses
`services.venue.HyperliquidVenueService`; progress.py re-exports
`runtime.http_progress` unchanged.

## Cross-test-file helper imports (preserve!)

`repositories_test.py` defines `_FakeCursor/_FakeConn/_FakeClient` (subclass of
QuestDbClient overriding `connect`/`executemany`); imported by
`repositories_load_test.py` AND `catalog_store_test.py`. Rewrite all three
import sites to the new package path.

## Per-file traps

- `worker.py`: hardest file. Module-level private cross-module imports from
  `adapters.driving.http.pair_ohlcv` (`_HL_EARLIEST`, `_HL_EARLIEST_MS`,
  `_MAX_FILL_BARS`, `_bar_ts_ms`, `ensure_venue_bars_in_catalog`,
  `timeframe_ms`). Tests monkeypatch `wmod.require_questdb_store`,
  `wmod.load_instrument_and_bars`, `wmod.ensure_venue_bars_in_catalog`,
  `wmod.process_job`, `wmod.fill_bars_toward_genesis` — every patched name must
  stay a module-level attribute of the copy.
- `cme_test.py`: several permanently-skipped tests
  (`@pytest.mark.skip(reason="stub data ...")`) import `DataCatalog`,
  `default_bars_downloader`, `micro_download` — decision D2: DROP the skipped
  tests and their unmappable imports (keep the three live mocked tests +
  `test_hit_or_take_to_side`); never ship F821s.
- `memory_store.py` (D3): `_QUESTDB_STORE_PATCH_TARGETS` mixes new-world paths
  (acl/driving/services) with old-world contexts paths. Faithful option:
  keep tuple verbatim except rewrite the entry pointing INTO the copied tree
  (`...catalog.adapters.download.worker` → new daemon path); the contextmanager
  skips missing modules via try/ImportError anyway, and originals still exist.
- `mappers_test.py`: behavioral asserts (`BTC-USD-PERP.HYPERLIQUID`,
  bar_type suffix `1-HOUR-LAST-EXTERNAL`) hold because mappers delegates to the
  already-new-world acl.nautilus.mapping — copy verbatim.
- `questdb_integration_test.py`: uses `QuestDbCatalogStore.require_from_env`
  directly, NO factory import — zero factory coupling. Copy verbatim.
- Row dataclasses: frozen slots dataclasses with lazy `from datetime import UTC`
  INSIDE `to_insert_params()` — preserve exactly (lint-friendly lazy import).

## Process rules for this task class

1. Inventory with find (exclude `__pycache__`, `data/`), then read EVERY file
   fully before writing its copy — half-known files produce silent drift.
2. Batch 2-4 reads per tool call; interleave writes once a subtree is fully read.
   This session burned nearly the whole budget on reads alone (56/61 done).
3. CREATE-ONLY verification at the end: `git status --porcelain` must show ONLY
   `??` untracked entries under the new roots and ZERO `M` lines anywhere.
4. Static gate before pytest: `ruff check --select F821 <new tree>` +
   `python -m py_compile` over all new files.
5. Scoped pytest per package (`pytest <new pkg> -q`, `-p no:cacheprovider`);
   if sibling packages are being created concurrently by another agent,
   collection may fail on THEIR half-written modules — wait-and-retry, do not
   "fix" their files.
6. devenv wrapper floods BOTH streams with prek/hook chatter on every
   invocation: capture with `devenv shell -- bash -c '<cmd> > /tmp/unique.txt 2>&1'`
   and read the file (unique names — parallel agents overwrite shared ones).

## Open items when resuming

1. Confirm destination directories with user (evidence: `adapters/driven/acl/questdb/`;
   providers/import-daemon placement unresolved).
2. Read the five unread download tests.
3. Apply decisions D1 (keep old-world sibling imports), D2 (drop skipped cme
   tests + their imports), D3 (rewrite only self-referential entries in
   `_QUESTDB_STORE_PATCH_TARGETS` / `_IMPORT_LOG_PREFIXES`).
4. Recompute `parents[N]` fixture anchors for the chosen depth.
5. Run the verification ladder (git-status → ruff F821 → py_compile → scoped pytest).
