# CME/MarketTaS Ingestion Into QuestDB (2026-08-24 session)

Backs the "CME/MarketTaS Ingestion Into QuestDB" section of SKILL.md.
Status at session close: bars phase COMPLETE (230,560 rows, all ~176 MES
days); l2/trades batch import running one day per invocation (~2 min/day,
all exit=0). Completeness check: `/tmp/verify_cme_complete.py` compares
QuestDB per-day presence against the source tree; watchdog cron
`8460b550e00e`. After COMPLETE, re-run:
`python -m andromeda backtest --log-level INFO --config python/andromeda/configs/andromeda.cme.example.json`.

## The operator question that started it

"`python -m andromeda backtest --config .../andromeda.cme.example.json` doesn't
work — I expected it to auto-import the CME data into QuestDB first."

Answer: it never did. Backtest only READS QuestDB. Ingestion is a separate
explicit `import download` step, and until this session even that path was
broken for real data.

## Call chain (verified, post-fix)

```
import download --venue cme --pair MES/USD --timeframe 1m --start .. --end ..
  → run_download_data (app.py)
  → CatalogService.require_from_env().download_bars / download_micro
      venue 'cme' selects provider in _default_bar_providers/_default_book_providers/_default_trades_providers
  → CmeBarsProvider / CmeBookProvider / CmeTradesProvider  (providers/cme.py)
  → MarketTaSDataSource(data_root)                          (providers/markettas_datasource.py)
  → QuestDB md_bar / md_l2 / md_trade, instrument_id '<BASE>-USD-PERP.CME'
```

- data_root resolution: `--markettas-data-root` flag → `config.markettas_data_root` → `DEFAULT_MARKETTAS_DATA_ROOT = notebooks/data` (`acl/cme/instruments.py:11`).
- Pair→symbol: `cme_root_from_pair` (`MES/USD` → `MES`); files matched by regex `^(?:Bests|TAS)_(?P<root>\S+)\s+(?P<month>[A-Za-z]{3}\d{2})(?:_OHLC)?\.parquet$`.
- `--catalog`/config `"catalog": "catalog"` is vestigial on this path; QuestDB is the sole destination.
- `bars` requires `--timeframe`; micro kinds (book_l2/trades) don't. `start`/`end` are REQUIRED (CLI or config.start/end).
- CME bars: native SoT is 1m — when a coarser TF is requested, download_bars ALSO persists the 1m base (`catalog_service.download_bars`).

## The stub regression (root cause of "does nothing")

Before 2026-08-24, `providers/markettas_datasource.py` was a hardcoded stub:

- `list_sessions()` returned `[date(2025, 9, 2)]`, ignoring `data_root`;
- `list_symbols()` returned `["MES","MNQ"]` for that magic date only;
- `load_session()` fabricated 1440 one-minute bars priced `100 + i*0.5`
  plus synthetic bests/tas frames;
- every caller swallows its FileNotFoundError with `continue`.

Effects an operator sees:
1. Only ever one day of invented MES data lands in QuestDB.
2. Re-running import reports `"n_rows": 0` because dedup filters existing
   timestamps → looks like the command silently does nothing.
3. Tests stay green because they're pinned to the same magic date/symbols
   (stub-contract drift, cf. `references/stub-contract-drift.md`).

The real filesystem datasource existed at `notebooks/markettas/datasource.py`
(278 lines) and was deleted in commit 1b387fa8 ("remove aurora and markettas
modules to simplify test suite"); the ACL stub took its place during catalog
dissolution. This session ported it back into the providers package with the
same `list_sessions/list_symbols/load_session/load_ohlc_only` surface so all
three CME providers work unchanged. Dropped dependency:
`from markettas import polars_runtime` (module no longer exists).

Normalization rules carried over from the original (all verified against real
files):
- Bests columns: `Time, Bid Volume, Bid Price, Ask Price, Ask Volume` — but raw
  files may carry `Offer Price/Offer Volume`; renamed to Ask. Rows where ALL
  quote fields are null are dropped (first row of each real file is null).
- OHLC column is literally `Open ` (trailing space) — renamed to `Open`.
- Timestamps: Date column (`%d/%m/%Y`) + Time column (`HH.MM.SS[.frac]`)
  combined per row; bests has NO Date column → session folder day is used.
- If no `_OHLC` parquet exists, 1m bars are derived from TAS
  (truncate to minute, first/max/min/last price, sum volume).

## Data landscape census (2026-08-24 tree)

- 202 `MarketTaSData_*` sessions under `notebooks/data`, spanning
  2025-09-02 … 2026-07-14.
- MES present in ~176 sessions: 150 with native `TAS_*_OHLC` parquets,
  26 TAS-only (derive), plus ~26 sessions without MES at all (other symbols:
  MBT weekends, MNQ Dec-2025 stretch, FESX/FGBL/MGC mixes).
- Real file sizes per session-day: Bests ≈420–490k rows, TAS ≈290–360k rows,
  OHLC ≈1.2k rows (1m bars). Full-range ingest is hours-scale, not minutes.

## dataset=all change

`--dataset` now defaults to `all` = bars + book_l2 + trades in ONE run
(previously default `bars`, which left l2/trades silently absent). Response
shape: top-level `n_rows` is the sum; per-kind counts under `results.bars`,
`results.book_l2`, `results.trades`. Micro kinds remain restricted to
venues synthetic|cme (error otherwise). Existing tests updated accordingly;
new test asserts call order `[bars, book_l2, trades]`.

## Purging fabricated rows (QuestDB has NO arbitrary DELETE)

Symptom after stub era: exactly 1440 md_bar rows for
`MES-USD-PERP.CME`, stamped 2025-09-02 00:00..23:59 UTC, prices ~100–820.

Working purge recipe (PGWire :8812, admin/quest/qdb):
```sql
SELECT DISTINCT to_str(timestamp, 'yyyy-MM-dd') FROM md_bar
 WHERE instrument_id LIKE '%.CME';          -- find affected days
ALTER TABLE md_bar DROP PARTITION LIST '2025-09-02';
```
Traps:
- `DELETE FROM ...` → `unexpected token [FROM]` (unsupported).
- Partition name must be the FULL day `yyyy-MM-dd` (table is partitioned BY DAY);
  `'2025-09'` is rejected with `'yyyy-MM-dd' expected`.
- A `DROP PARTITION LIST` for a non-existent name still reports success —
  always re-count afterwards: `SELECT count(*) FROM md_bar WHERE instrument_id LIKE '%.CME'`.

## Running long imports (ctx_shell-safe pattern)

Foreground hits the ~110s cap and the timeout kill takes the import with it.
Detached launch instead:

```bash
nohup .devenv/state/venv/bin/python /tmp/run_import.py > /tmp/cme_import.log 2>&1 &
```

with a launcher script setting `PYTHONPATH=python` and
`QUESTDB_PG_URL=postgresql://admin:quest@127.0.0.1:8812/qdb`, calling
`.devenv/state/venv/bin/python -m andromeda import download --config
python/andromeda/configs/<cfg>.json ...` (repo-root-relative config path).
Progress probe while it runs:

```sql
SELECT count(*), min(timestamp), max(timestamp) FROM md_bar WHERE instrument_id LIKE '%.CME'
```

(md_l2/md_trade likewise). Note `python -m andromeda` needs PYTHONPATH=python —
bare invocation fails with "No module named andromeda" since the package lives
under `python/andromeda/`.

## Test-suite notes from this session

- Rewrote `markettas_datasource_test.py` fixtures to seed REAL-schema parquets
  via polars (Offer→Ask variants included) instead of asserting against the
  stub's magic date; skip writing the `_OHLC` fixture unless the test wants it
  (a helper that unconditionally seeds OHLC makes the TAS-derived-bars test
  silently see OHLC-file numbers — cost several debug rounds).
- TAS rows `23.00.00.0116` / `23.00.01.0145` truncate to the SAME minute →
  one derived bar; don't assume two.
- app_main_test container doubles needed `historical_runner()` (returns object
  whose `.run(...)` yields the fake result) and a `freqai_service()` double
  after parallel-session DI wiring moved those onto the container; class-level
  monkeypatching of HistoricalRunnerService.run/FreqaiService methods no longer
  reaches through the Singleton — patch create_container instead.
- Ruff triage on shared dirty files: classify vs HEAD before fixing
  (F401/I001/F841 in app.py were the parallel session's, not ours).
