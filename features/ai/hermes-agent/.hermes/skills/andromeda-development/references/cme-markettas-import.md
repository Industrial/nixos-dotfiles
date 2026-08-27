# CME / MarketTaS → QuestDB import (operator recipe, verified 2026-08-24)

## Pipeline
1. Source: `notebooks/data/MarketTaSData_<YYYY-MM-DD>/` day folders holding per-symbol parquets:
   `Bests_<ROOT> <MonYY>.parquet` (top-of-book quotes, ~400-500k rows/day),
   `TAS_<ROOT> <MonYY>.parquet` (trade prints), optional `TAS_..._<MonYY>_OHLC.parquet`
   (native 1m bars; preferred over TAS-derived bars).
2. `adapters/driven/acl/providers/markettas_datasource.py::MarketTaSDataSource` discovers
   sessions/symbols and normalizes: Offer Price/Volume → Ask*, `'Open '` trailing-space column
   rename, `Date` (dd/mm/yyyy) + `Time` (`HH.MM.SS[.frac]`) strings → timestamp, all-null quote
   rows dropped, OHLC derived from TAS when no _OHLC file exists. Ported 2026-08-24 from the
   deleted `notebooks/markettas/datasource.py` (found via git archaeology). NEVER regress to the
   hardcoded stub — it returned fabricated 1440-row frames for magic date 2025-09-02 and silently
   ingested invented prices (second live instance of stub-contract drift).
3. `CmeBarsProvider` / `CmeBookProvider` / `CmeTradesProvider` consume `load_session` unchanged;
   QuestDB instrument tag = `<COIN>-USD-PERP.CME` (e.g. `MES-USD-PERP.CME`).

## Commands
```
python -m andromeda import download \
  --config python/andromeda/configs/andromeda.cme.example.json \
  --venue cme --pair MES/USD --timeframe 1m \
  --start <ISO-tz-aware> --end <ISO-tz-aware>
```
- `--dataset all` is the DEFAULT (bars + book_l2 + trades; per-kind counts under `results`).
- start/end REQUIRED (CLI or config.start/end).
- `import up` deliberately REFUSES venue cme/markettas (`refuse_cme_import_up`).
- Backtest after: `python -m andromeda backtest --log-level INFO --config <cfg>`.

## OOM trap → batch per session-DAY
One wide window makes `CatalogService.download_micro` accumulate EVERY snapshot in memory before
writing: >15 GB RSS and counting for ~176 MES sessions (~75M rows). Batch per day (~0.5–1M rows,
~2 min/day). Bars dedupe via existing_ts so overlapping ranges are safe. Long-term TODO: chunk
inside download_micro itself.

## Detaching long imports from the agent session
Plain `&`/nohup children get SIGKILLed when the ctx_shell call tears down. Spawn via Python
`Popen(["setsid", venv-python, "-u", script], start_new_session=True)` logging to a file; poll
with `grep -c "exit=0" log`. ~176 sessions ≈ 5–6 h wall clock.

## QuestDB purge (NO DELETE support)
`DELETE FROM` raises "unexpected token [FROM]". Tables are DAY-partitioned:
```
ALTER TABLE md_bar DROP PARTITION LIST '2025-09-02';
```
Value must match the DAY stamp ('yyyy-MM-dd'); a month string errors. Verify with
`SELECT count(*) ... WHERE instrument_id LIKE '%.CME'`. Used to purge the stub-era fabricated bars.

## Schema notes (PGWire, postgresql://admin:quest@127.0.0.1:8812/qdb, QUESTDB_PG_URL in devenv.nix)
- md_l2 price/size cols are ARRAY-typed: `bid_prices/ask_prices/bid_sizes/ask_sizes` →
  `.list.first()` for top-of-book. NOT flat bid_price columns.
- md_trade side column is `aggressor` (buy/sell), not `side`.
- Day extraction: `to_str(timestamp,'yyyy-MM-dd')` (no date() function).

## Verification pattern
Distinct day-sets in md_bar/md_l2/md_trade (`instrument_id LIKE '%.CME'`) vs the set of MES
session folders; emit missing-lists per table. Batch runner logged per-day JSON results
(bars/l2/trades n_rows) for cross-checking against source parquet row counts.

## Flow-momentum negative result (quant)
5-min signed aggressor volume: Spearman IC +0.167 vs fwd 1m return (t≈22, hit rate 17/17 days,
monotone quintiles Q5−Q1 ≈ 0.80 bp/min) — and UNTRADABLE: entry at next-bar close flips to
−0.87 bp/trade; recomputing the signal with a 30 s decision lag erases the edge entirely.
Same-minute lookahead artifact, not momentum. Gate + primitives shipped:
`python/andromeda/research/flow_momentum_study.py` (`lag_gate`, `signed_flow`, `flow_signal`,
`zscore_by_day`, `pick_events`, `event_pnl`, `build_price_lags`), synthetic-tested.
