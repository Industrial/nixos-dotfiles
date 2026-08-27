# CME / MarketTaS offline ingest + backtest CLI (verified 2026-08-24)

Session evidence: operator ran `backtest` with `andromeda.cme.example.json` expecting
auto-import from MarketTaS into QuestDB; then `import download` appeared to "do
nothing". Root causes below, all verified against source.

## CLI entrypoint map

- Entrypoint is `python -m andromeda` (`python/andromeda/__main__.py` →
  `adapters/driving/cli/app.py::main`). No console script in either pyproject.
- `backtest` subcommand flags (app.py build_parser): `--config` (required),
  `--catalog`, `--venue`, `--start/--end` (ISO8601 filters), `--log-level`.
  It ONLY READS whatever is already in QuestDB. There is no auto-import step.
- Ingest is a separate explicit command:
  `python -m andromeda import download --config <cfg> --venue cme --pair MES/USD
  --timeframe 1m --start <iso> --end <iso>`
- `--start/--end` are REQUIRED for download (CLI flag or `config.start/end`;
  `andromeda.cme.example.json` has neither — pass flags explicitly).
- Datasets: `--dataset` defaults to **`all`** (bars + book_l2 + trades per
  invocation; landed 83cec911 — previously default `bars`, which left
  l2/trades silently absent). Micro kinds restricted to synthetic|cme.
- `import up` deliberately refuses CME/MarketTaS (`refuse_cme_import_up()` in
  `_cmd_import_up`) — the passive daemon is HL-only by design.
- MarketTaS data-root resolution order for downloads:
  `--markettas-data-root` flag → `config.markettas_data_root` → hardcoded
  `notebooks/data` (`DEFAULT_MARKETTAS_DATA_ROOT`,
  adapters/driven/acl/cme/instruments.py).
- Separate flavor: `lopezdeprado-backtest --config ...` = offline Rust label path
  via ldp_py_bridge (no FT catalog).

## Flow (bars)

1. `import download` → `run_download_data` →
   `CatalogService.require_from_env().download_bars(...)` (app.py ~L289)
2. venue key `cme` selects `CmeBarsProvider` in `_default_bar_providers`
   (services/catalog_service.py ~L509)
3. Provider walks MarketTaS day folders via `MarketTaSDataSource`, converts
   session OHLC to native 1m `BarRow`s (resample if TF≠1m; CME also always
   persists the 1m SoT alongside a coarser request), dedups against existing
   QuestDB timestamps (`_existing_bar_ts`), writes gap-free contiguous runs to
   `md_bar`.
4. `book_l2` → `CmeBookProvider` (Bests → top-of-book snapshots → `md_l2`);
   `trades` → `CmeTradesProvider` (TAS Hit/Take → sell/buy ticks → `md_trade`).

## THE STUB — production datasource is fake (found 2026-08-24)

`MarketTaSDataSource` (adapters/driven/acl/providers/markettas_datasource.py)
is a hardcoded test stub, docstring says so:

- `list_sessions()` returns `[date(2025, 9, 2)]` — ignores `data_root` entirely.
- `list_symbols()` returns `["MES", "MNQ"]` only for that magic date.
- `load_session()` fabricates a dummy 1440-row 1m frame (`close = 100 + i*0.5`)
  plus synthetic bests/tas frames for that date+root combo;
  raises FileNotFoundError otherwise — which every provider caller swallows
  with `continue`.

Consequences:

- The ~200 real `notebooks/data/MarketTaSData_*` folders are NEVER read by any
  CME provider. A passed/configured `markettas_data_root` changes nothing.
- Operator signature of the trap: `import download` completes instantly,
  reports success with tiny/zero `n_rows`. Zero specifically happens when the
  single fabricated day was already ingested by an earlier run or test — the
  dedup filter drops it and nothing else exists.
- Why suites stay green: fixtures pin the same fiction
  (instruments_test creates `MarketTaSData_2025-09-02/Bests_MES Sep25.parquet`,
  expects `[MES/USD, MNQ/USD]`; passes only because of the hardcoded date).
  Stub-contract drift instance #2 — INVERTED: here the PRODUCTION source is
  the stub while tests encode its fantasy as a contract.

## Git archaeology (where the real one went)

A real filesystem-backed datasource existed: `notebooks/markettas/datasource.py`
(278 lines, commit e5df2899): day-dir regex `MarketTaSData_(YYYY-MM-DD)`,
contract regex `(Bests|TAS)_ROOT MonYY.parquet`, frozen `SessionBundle`, session
timestamp normalization (`_combine_session_ts`), multi-threaded Polars.
Deleted in 1b387fa8 ("remove aurora and markettas modules to simplify test
suite"). The ACL stub took its place during catalog dissolution (7f2b2ee2) and
was later "fixed" only in fixture shape (23485e3a added Bid/Ask columns to the
fabricated bests frame so CmeBookProvider's contract test passes).

## Fix direction (agreed, NOT yet executed) → RESOLVED (all follow-ups complete 2026-08-24)

Port DONE — `markettas_datasource.py` now contains the real filesystem-backed
datasource (day-dir regex discovery across all sessions, contract-file matching,
Offer→Ask rename, `"Open "` trailing-space column fix, Date+Time→timestamp
attachment, all-null-quote row drop, TAS→1m-OHLC derivation when no `_OHLC`
file exists). Tests rewritten to seed REAL parquet fixtures. Follow-ups ALL
landed (see SKILL.md "CME/MarketTaS import" + canonical reference for detail):

- Test-helper OHLC-seeding bug fixed (`_seed_real_frames` guards the OHLC write).
- `--dataset` defaults to `all` (bars+book_l2+trades; per-kind counts under
  `results.*`), commit 83cec911.
- 1,440 fabricated stub bars PURGED via
  `ALTER TABLE md_bar DROP PARTITION LIST '2025-09-02'` — QuestDB has NO
  arbitrary DELETE; partition name must be full `yyyy-MM-dd`; re-count after
  (a wrong-name DROP still reports success). md_* rows key on `instrument_id`
  SYMBOL (`MES-USD-PERP.CME` via mapping.instrument_id_for_pair) — there is no
  pair/venue column pair to group by.
- Full-range ingest is hours-scale → run detached (setsid + log file) and
  batch one session-day per invocation; multi-month single-call windows OOM'd
  >17 GB RSS until download_micro got 50k-row chunked writes (3cb4b4c6).

Debug trap worth keeping: the TAS-derived-bars test failed ONLY under pytest,
passed inline — cause was the shared test helper unconditionally seeding the
OHLC file. When a test-only failure resists inline reproduction, diff what
each harness actually seeds before suspecting imports or caching.

## Meta-rules that generalize

## Meta-rules that generalize

- When an operator ingest writes zero rows: check (a) dedup-vs-existing
  filtering first, then (b) whether the provider's data source is REAL at all —
  grep the loader for hardcoded return values before trusting config keys.
  A config key being plumbed through does not mean anything reads it.
- A stub can sit under a production code path for weeks if every consumer
  swallows its failure mode (`except FileNotFoundError: continue`) and test
  fixtures mirror the stub instead of the filesystem reality. Audit signal:
  does any test construct REAL input files AND exercise the real loader?
