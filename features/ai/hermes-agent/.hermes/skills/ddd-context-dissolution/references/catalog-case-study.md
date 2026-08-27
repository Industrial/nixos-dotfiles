# Catalog dissolution case study — EXECUTING (wave 1 in flight, 2026-08-23)

Status: plan APPROVED by user 2026-08-23 ("Approve" = execute all waves with the
stated defaults, no re-asking). Wave 0 + wave 1 dispatched. Everything below is
the planning-time placement map; UPDATE with execution evidence as waves land
(mark each section verified/changed, like strategy-host-case-study does).

## Execution evidence so far

Wave 0 (quiet-tree gate): HEAD moved under us mid-session — instrument_map
dissolved by the parallel session (0043a011), one fewer candidate. The shared
INDEX held staged deltas inside contexts/catalog/** → per user's original order,
wave 1 flipped to STRICTLY CREATE-ONLY: zero edits/mv/deletes to existing files;
demolition stays wave 4. Verified via `git status --porcelain contexts/
composition conftest.py` showing nothing touched by us.

Wave 1 dispatched as THREE parallel subagents:
A) acl/questdb (+testing memory_store with patch-targets rewritten to the single
   new-world choke point `CatalogService.require_from_env`) + acl/providers/* +
   import_daemon (SQLite job_store stays verbatim).
B) domain/bar_math (resample+merge MERGED; equity SOURCE_* constants
   canonicalized here per the duplication ruling) + domain/catalog_requests
   (request VOs; provider allow-lists RELOCATED to downloader services) +
   equity_listing/acl.ibkr.symbology split.
C) services/catalog_service.py (ONE class CatalogService incl. absorbed
   catalog_loader as load_instrument_and_bars) + services/catalog/{micro_loader,
   downloader,micro_downloader,equity_sources,equity_service,equity_importer,
   backtest_runner} + acl/hl/capture/hl_micro_sync.

Worker-B scope ABSORBED into parent after its subagent died with an empty reply;
delivered + verified green directly: domain/bar_math(+test),
domain/catalog_requests(+test), domain/equity_listing(+test),
acl/ibkr/symbology(+test). 35 tests pass, ruff F821 clean. Incident logged: first
write of acl/ibkr/__init__.py clobbered the EXISTING package init (created by the
same-day instrument_map dissolution); caught via git diff within a minute,
HEAD content restored verbatim then re-exports appended — see SKILL.md
write_file-overwrite bullet.

## User order

Keep ONLY the QuestDB catalog parts for saving data — no more parquet. Leave the
whole contexts/catalog code in place; create the new code beside it. Then
refactor all other code to the new CatalogService; once all functionality is
replaced, remove the old catalog code. Tests stay green throughout.
This is the first PARALLEL-EXISTENCE dissolution (create → cut over → demolish).

## Recon numbers (verified 2026-08-23)

- contexts/catalog = 163 py files, 12,965 LOC (incl. __pycache__-free .py only).
- Four mixed concerns: QuestDB store (KEEP), ingest pipelines (KEEP, moved),
  parquet/jsonl legacy backend (DIES), pure math + vendor symbology (SPLIT).
- `require_questdb_store()` (application/catalog_factory.py) is the de-facto
  seam: ~20 production consumers across services/, contexts/{execution,
  freqai_host}, adapters/{driven/acl,driving}, composition/, test/proofs/.
- Repo conftest.py imports MemoryQuestDbStore from contexts/catalog/testing on
  EVERY test; memory_store._QUESTDB_STORE_PATCH_TARGETS hardcodes NINE module
  paths incl. `adapters.download.worker` and http/cli modules.
- No references outside python/andromeda.

## Planned placement map

| New home | Gets |
|---|---|
| services/catalog_service.py | ONE class CatalogService: require_from_env(), load/write_bars, load_instrument_and_bars (absorbs catalog_loader), micro load/write/sync, md-row passthroughs |
| services/catalog/ package | micro_loader.py (from micro_features), equity_service.py (write_us_slice/catalogize_merged), importer.py, bar_loader |
| adapters/driven/acl/questdb/ | client, repositories(+load test), rows/, mappers(+test), catalog_store(+test), integration test — git mv as one unit |
| adapters/driven/acl/providers/<name>/ | hyperliquid, cme, crypto_spartan, ohlcv_1m, stooq, markettas_datasource, synthetic(+micro) + colocated tests (venue precedent) |
| adapters/driven/acl/hl/capture/ | hl_micro sync internals + hl_micro_test/hl_micro_nan_test |
| domain/bar_math.py | resample_bars + ensure_timeframe + merge_bars (resample.py+equity_merge.py); purity-gate list same commit |
| domain/equity_listing.py + adapters/driven/acl/ibkr/symbology.py | ibkr_symbology split: domain types vs NT builders; fix nautilus/mapping.py function-local imports |
| adapters/driven/import_daemon/ | daemon, enqueue, worker, import_job, job_key, job_store (SQLite stays), progress, logging_setup |
| DIES wave 4 | adapters/parquet/**, backfill_questdb*, ft_import*, equity_import/pipeline/raw/merge, download.py, micro_download.py, application/ ports, DataCatalog |

## Waves

0. Quiet-tree gate + baseline scoped green (magnets: makers.py,
   application_container.py, application_test.py, ddd gates).
1. Moves + new CatalogService land beside old context (zero consumer rewires
   except mechanical intra-import rewrites). pytest --co after every
   move-to-domain; ruff F821 sweep.
2. Composition cutover: catalog_service providers.Singleton (never Factory);
   DataCatalog threading → plain Path where it was only an artifacts root;
   §5 identity tests updated.
3. Consumer cutover: scripted rewrite of ALL remaining contexts.catalog imports
   AND monkeypatch STRING targets; leftover grep == 0; scoped suites per group.
4. Demolition: git rm -r contexts/catalog; tombstone test in layout gates;
   purity gate += domain/bar_math.py, domain/equity_listing.py; ARCHITECTURE.md
   row; full-tree pytest green.

## Open decision points (APPROVED with defaults 2026-08-23)

Q1 downloaders stay separate classes in services/catalog/ — APPROVED yes.
Q2 equity_import/pipeline/raw die; equity_service keeps write_us_slice/
   catalogize_merged — APPROVED yes.
Q3 backfill_questdb + ft_import die un-replaced (parquet→QuestDB migration
   tooling, job done) — APPROVED yes.
Q4 memory_store relocates to acl/questdb/testing in wave 1 with conftest +
   patch-target rewrite — APPROVED yes.

## Dead-backend vs vendor-input distinction

Parquet/jsonl under adapters/parquet = OUR storage format → dies.
MarketTaS features.parquet reader (micro_features.sync_catalog_micro_from_features)
reads an EXTERNAL vendor file → survives inside micro_loader.

## Artifacts

- .cursor/plans/catalog-dissolution-catalogservice.plan.md
- .maestro/specs/catalog-dissolution-catalogservice.md
- .maestro/missions/catalog-dissolution-catalogservice.execution.md
- history/2026-08-23T1945Z-catalog-dissolution-plan.md

## Wave 1 import-substitution table (the mechanical core)

Old → new (most-specific-first when scripting):
- contexts.catalog.adapters.questdb → adapters.driven.acl.questdb
- contexts.catalog.testing.memory_store → adapters.driven.acl.questdb.testing.memory_store
- contexts.catalog.adapters.providers.<x> → adapters.driven.acl.providers.<x>
- contexts.catalog.adapters.download → adapters.driven.import_daemon
- `from ...catalog.download import` request VOs → andromeda.domain.catalog_requests
- contexts.catalog.resample / equity_merge → andromeda.domain.bar_math
- contexts.catalog.micro_features → andromeda.services.catalog.micro_loader
- require_questdb_store() call sites → CatalogService.require_from_env()
- contexts.catalog.ibkr_symbology → domain.equity_listing + acl.ibkr.symbology (split)
- contexts.catalog.equity_raw → services.catalog.equity_sources

Unmapped-import rule for copied files: inline-copy tiny pure helpers with a
`# inlined from contexts/catalog/<orig>` comment; otherwise omit the dependent
path and REPORT — never invent a mapping.

## Verification evidence shape (wave 1, worker-B scope)

`QUESTDB_PG_URL=unused:// ../.devenv/state/venv/bin/python -m pytest
andromeda/domain/bar_math_test.py andromeda/domain/catalog_requests_test.py
andromeda/domain/equity_listing_test.py andromeda/adapters/driven/acl/ibkr -q`
→ EXIT=0, 35 passed; ruff F821 clean incl. repaired acl/ibkr/__init__.py.

## Worker-A absorption (parent-executed scripted copy, 2026-08-23 later same day)

A timed out at its 600s cap (50 api_calls) having produced ZERO files — died
during source reading. Absorbed into the parent as ONE deterministic
execute_code pass over the dispatch's own substitution table:

- 56 files copied (questdb tree + testing/memory_store, 8 providers + tests,
  import_daemon tree) with ordered most-specific-first string substitutions;
  per-file substitution counts printed; leftover grep over the three trees.
- Straggler classes found ONLY by the leftover grep, each fixed in a second
  scripted pass: module-local `from ...adapters.providers import x` inside
  provider TESTS (the table only mapped dotted paths); logging_setup's logger
  NAME string (`andromeda.contexts.catalog` → `andromeda.import_daemon`);
  memory_store `_QUESTDB_STORE_PATCH_TARGETS` replaced wholesale by the single
  choke point tuple `("andromeda.services.catalog_service",)` with stub lambdas
  widened to `lambda *_, **__: store` (classmethod receives cls);
  worker.py rewritten to the seam (`svc = CatalogService.require_from_env()`;
  `svc.load_instrument_and_bars(...)`), dead DataCatalog threading removed,
  `catalog_open=None` pass-through preserved; permanently-skipped cme_test
  stub tests lost their DataCatalog lines and call the no-catalog
  default_bars_downloader signature.

## Worker-C production code absorbed by parent (tests still pending)

Parent wrote directly: services/catalog_service.py (ONE class: bars +
load_instrument_and_bars absorbing application/catalog_loader verbatim, micro,
md-row passthroughs, sync delegates to capture/micro_loader),
services/catalog/{__init__, equity_sources, downloader (provider allow-list
moved here from the request VO; legacy `catalog=` slot kept as unused Any for
positional compat), micro_downloader (lazy synthetic imports; store resolved
via `self._svc().store`), micro_loader (parquet sidecar functions DELETED;
sync_catalog_micro_from_features now writes MdMicroRow rows through
svc.write_micro; features_json json.dumps per row), backtest_runner
(function names stable: freqai_fe_warmup_bars/_load_start_with_warmup/
_ensure_micro/run_catalog_backtest; catalog_path = artifacts root only)},
acl/hl/capture/{__init__, hl_micro_sync} (verbatim port minus _catalog_root;
`sync_catalog_micro_from_hl = sync_micro_from_hl` legacy alias kept because
runner_service + proofs still use the name).
NOTE: micro_loader first write went out malformed (truncated mid-thought) —
caught by re-reading the source and rewriting the whole file from
micro_features.py L73-218; never ship a half-recalled port, re-read the
original.

## Mock-seam shadowing trap (cost two debug cycles — remember for wave 3)

Patching `CatalogService.require_from_env` to return `MagicMock()` while ALSO
patching `CatalogService.load_instrument_and_bars` at class level does NOT
work: the instance returned by the patched classmethod is a bare mock whose
auto-created CHILD attribute shadows the class-level patch, so the fake method
never fires (symptom: ValueError from real code paths, or wrong call counts).
Fix: build ONE configured fake service
(`fake_svc = MagicMock();
fake_svc.load_instrument_and_bars.side_effect = fake_fn`) and patch ONLY
require_from_env to return it. Applies to every seam-based consumer cutover:
patch the FACTORY, inject a fully-configured fake, never mix class-method
patches with bare-mock instances.

## Integration-test sentinel gating

questdb_integration_test.py gated on
`os.environ.get(ENV_QUESTDB_PG_URL, "").startswith("postgresql://")` — the
conftest escape-hatch value `unused://` previously satisfied the old truthiness
check and triggered a real PGWire ping. Any relocated optional-live test needs
the same scheme-aware skip.

## Wave-1 verification state (end of this session)

- Worker-B scope: EXIT=0, 35 passed (domain/bar_math_test,
  catalog_requests_test, equity_listing_test, acl/ibkr incl. venue family).
- Worker-A scope + parent-written service/capture modules:
  EXIT=0, 138 passed / 5 skipped / 0 FAILED over acl/questdb +
  import_daemon + acl/providers (/tmp/wave1_a5.log, /tmp/wave1_turn_verify2.log);
  ruff F821+E501 clean over services/catalog*, services/catalog_service.py,
  acl/hl/capture. py_compile clean on every new file.
- One verifier-facing slip: a scoped pytest invocation named
  services/catalog_service_test.py BEFORE it existed → exit 4 (bad arg), not a
  product failure; re-ran with existing targets. Only claim green with the log
  path + counts.

## Wave 2+3 execution state (2026-08-24, this session)

Wave 2 LANDED (575a632e, container cutover to CatalogService) plus interleaved
execution-mission commits through 053c2cb4. Wave 3 consumer cutover was found
STAGED-BUT-UNCOMMITTED in the shared worktree (~140 paths: all external
referrers already rewritten, nt_book/nt_ctx/nt_trades git-mv'd to
acl/nautilus/, tracker artifacts + foreign questdb/artifacts debris mixed into
the same index). This session closed the remaining gaps:

- FAMILY MOVE completion (spec ruling #5): the 4 orphaned NT parquet tests
  (nt_book/nt_ctx/nt_trades/nt_book_mixed_delta _test.py) git-mv'd to
  acl/nautilus/ beside their relocated writers; stale imports rewritten with
  exact-count asserts; provenance comments naming contexts/catalog neutralized.
  Before the move these orphans made full-tree collection ERROR (exit 2).
- Production fixes: `_sync_hl_micro_or_pending` now calls the CatalogService
  facade verb (spec contract; was bypassing via adapter free-function);
  `_paper_run` reads `forward.artifacts_root` (the `.catalog.root` attribute
  died in w2 — its best-effort except swallowed the AttributeError and six
  run-artifact tests failed on missing directories); app.run_download_data
  dropped the deleted `data_catalog` provider (downloaders resolve via env);
  retired commands raise BotControlError not SystemExit (ft-data import;
  catalog backfill-questdb — whose import pointed at
  services/catalog/backfill_questdb which NEVER EXISTED; the module dies in
  wave 4 per Q3).
- Test seam refreshes: dead module-level `require_questdb_store` /
  module-attr `load_instrument_and_bars` patches rewritten to class-level
  string-target stubs (`"…CatalogService.require_from_env"` classmethod form;
  `"…CatalogService.load_instrument_and_bars"` plain lambda form) across
  freqai operator_test (now services/freqai/operator_test.py — foreign package
  move landed mid-session), analysis_rpc_test, pair_ohlcv_test,
  backtest_rpc_test (dropped dead DataCatalog patches), app_main_test
  (fakes gained callable catalog_root, raw_config/session for _cmd_serve_api).
- conftest bridge for parallel existence: autouse fixture now ALSO stubs legacy
  `contexts.catalog.adapters.questdb.catalog_store.QuestDbCatalogStore.
  require_from_env` to the same memory store (legacy equity_pipeline still
  resolves stores that way until demolition). Dies with wave 4.

### Env lesson (corrects earlier guidance in this file)

Wave-1 evidence commands used `QUESTDB_PG_URL=unused://`; that sentinel is now
known BROKEN for batteries: conftest's autouse memory-store stub activates only
when the var is UNSET, so any value yields a half-stubbed run (psycopg2
`invalid dsn` / `CatalogError: QUESTDB_PG_URL is not set` noise). Full-tree
battery = `env -u QUESTDB_PG_URL … -m pytest`. HEAD baseline under the same env
was itself red (31 failures incl. the pre-existing data_catalog provider call)
— always diff worktree-vs-HEAD failure sets under IDENTICAL env before
attributing.

## Remaining work

- WAVE 3 CLOSE-OUT (next session, in order): (1) scoped pytest env-unset over
  the touched surfaces (services/freqai/operator_test.py at its NEW path,
  driving/http trio, app_main_test, paper_session tests, equity_import_test);
  (2) full battery `env -u QUESTDB_PG_URL` + ruff F821/E501 sweep; (3)
  path-scoped commit of python/andromeda/** + history/ plan archive — EXCLUDE
  foreign debris (.maestro/** tracker files staged by other sessions,
  python/questdb/artifacts/* test outputs) and do NOT sweep the foreign
  freqai package move (services/freqai_*.py → services/freqai/, staged by the
  parallel session — their commit owns it).

- C's TEST ports: catalog_service_test, micro_loader/downloader/
  micro_downloader/equity_sources/equity_importer/backtest_runner tests,
  acl/hl/capture unit tests (+ nan variant), with monkeypatch STRING targets
  rewritten to the new module paths.
- Wave 2 composition cutover (Singleton catalog_service; DataCatalog→Path).
- Wave 3 consumer sweep (~20 files; string targets included; leftover grep==0;
  apply the mock-seam rule above when porting patch-heavy tests).
- Wave 4 demolition + tombstone + purity gate (bar_math, equity_listing) +
  ARCHITECTURE.md row.
