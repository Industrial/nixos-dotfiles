# Andromeda operator CLI + CME/MarketTaS ingest (2026-08-24 session)

> NOTE: this reference overlaps heavily with `cme-markettas-import-and-questdb.md`
> (canonical for the import pipeline + QuestDB ops). Kept for the CLI flag
> tables; prefer the canonical file for ingestion/purge/research detail.

## CLI entrypoint facts

- Entrypoint: `python -m andromeda` — `python/andromeda/__main__.py` delegates to
  `adapters/driving/cli/app.py::build_parser`. There is NO console-script
  entrypoint in any pyproject (`[project.scripts]` absent everywhere).
- `backtest` reads ONLY existing QuestDB `md_bar` rows for the configured
  venue/pair/timeframe. It performs NO automatic import. Empty catalog →
  `CatalogError: no QuestDB bars for venue=...` or a silently empty result.
- CME ingest is a separate explicit step: `import download --venue cme ...`.
  `import up` REFUSES cme/markettas venues by design (`refuse_cme_import_up()`,
  app.py `_cmd_import_up`).
- `--dataset` defaults to **`all`** (bars + book_l2 + trades per invocation;
  landed 83cec911). Response: top-level `n_rows` is the sum; per-kind counts
  under `results.bars` / `results.book_l2` / `results.trades`. Micro kinds
  restricted to venues synthetic|cme.
- start/end REQUIRED for download (CLI flags or config.start/end; the cme
  example config carries neither → error without flags).

## MarketTaS day-folder format (real files, verified)

- Root: `notebooks/data` (config key `markettas_data_root`; flag
  `--markettas-data-root`; hardcoded default `notebooks/data` in
  `adapters/driven/acl/cme/instruments.py::DEFAULT_MARKETTAS_DATA_ROOT`).
- Session dirs: `MarketTaSData_YYYY-MM-DD/` (202 dirs on disk, 2025-09-02 …
  2026-07-14). Non-matching dirs (e.g. `crypto_spartan`, `ohlcv_1m`) ignored.
- Per symbol/day: `Bests_<ROOT> <Mon><YY>.parquet` (top-of-book), 
  `TAS_<ROOT> <Mon><YY>.parquet` (time-and-sales), optionally
  `TAS_<ROOT> <Mon><YY>_OHLC.parquet` (prebuilt 1m bars). Contract regex:
  `^(?:Bests|TAS)_(?P<root>\S+)\s+(?P<month>[A-Za-z]{3}\d{2})(?:_OHLC)?\.parquet$`.
- Real schemas: Bests = `Time, Bid Volume, Bid Price, Ask Price, Ask Volume`
  (Time like `22.58.13.7690`; some rows all-null quotes); TAS =
  `Date(dd/mm/YYYY), Time(H.M.S.f), Traded Volume(i64), Traded Price,
  Hit or Take`; OHLC = `Date, Bar Time(H.M.S), Open<TRAILING SPACE>, High, Low,
  Close, Volume Traded`. ~350k–490k rows/symbol/day.
- Coverage reality check: MES exists in ~176 of 202 sessions (150 with native
  _OHLC, 26 TAS-only); 26 sessions lack MES entirely (other symbols only).

## The stub bug (found + fixed 2026-08-24)

The ACL `MarketTaSDataSource` was a hardcoded stub ("Stub for MarketTaS data
source"): `list_sessions()` returned `[date(2025,9,2)]` ignoring data_root;
`load_session()` fabricated a synthetic 1440-row day. Consequences:

- `import download` ingested ONE day of invented prices and wrote nothing for
  any other session — looked like "the command does nothing".
- Dedup made repeat runs no-ops: `download_bars` skips rows whose timestamp
  already exists (`_existing_bar_ts`), so the fabricated day already present →
  `n_rows: 0`.
- Tests stayed green because they were pinned to the same fiction
  (`instruments_test.py` seeded `MarketTaSData_2025-09-02` with MES+MNQ files
  and the stub hard-coded exactly that date/symbol set) — textbook stub
  contract drift.
- QuestDB carried the pollution: 1,440 rows `MES-USD-PERP.CME` on 2025-09-02
  with fake prices (~6480 vs real ~7558 that day). Purged via
  `ALTER TABLE md_bar DROP PARTITION LIST '2025-09-02'` (QuestDB has NO
  arbitrary DELETE; partition name must be the full `yyyy-MM-dd` — see
  canonical reference for traps: a wrong-name DROP still reports success, so
  always re-count after).

Fix applied: ported the real filesystem datasource back from deleted commit
70efb24b (`notebooks/markettas/datasource.py`) into
`adapters/driven/acl/providers/markettas_datasource.py`, keeping the class
surface (`list_sessions/list_symbols/load_session`) so all three CME providers
work unchanged. Dropped the removed `markettas.polars_runtime` import.

## QuestDB row-id conventions (for verification queries)

- Tables keyed by `instrument_id` SYMBOL, e.g. `MES-USD-PERP.CME`,
  `BTC-USD-PERP.HYPERLIQUID` (from `instrument_id_for_pair(pair, venue)` in
  `adapters/driven/acl/nautilus/mapping.py`). md_bar has NO `pair` column —
  group by `instrument_id`.
- PGWire: `postgresql://admin:quest@127.0.0.1:8812/qdb` (env
  `QUESTDB_PG_URL` from devenv.nix).
- Verification pattern: per-table
  `SELECT instrument_id, count(*), min(timestamp), max(timestamp) FROM md_* 
  WHERE instrument_id LIKE 'cme%' GROUP BY instrument_id` and compare counts
  against source parquet row counts per session.

## Shell-policy notes hit this session

- `python3 -c` inline code AND heredoc-python are permanently blocked in this
  repo's ctx_shell — write probes to `/tmp/probe_*.py` and run
  `.devenv/state/venv/bin/python /tmp/probe_X.py`.
- A single blocked segment rejects the ENTIRE shell pipeline before it runs.
- A repo-wide `grep -rn` over the whole tree can exceed the 110 s foreground
  cap and auto-background; scope greps with paths or use search tools instead.
- lean-ctx enforces a search-rate limit (~12 searches/300 s): batch regex
  patterns into one call with `queries=[...]` instead of many sequential calls.
