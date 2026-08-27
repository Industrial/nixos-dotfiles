# CME / MarketTaS Import Pipeline & QuestDB Ops

Session-verified detail behind the SKILL.md "CME/MarketTaS import" section
(2026-08-24). Companion: `references/cme-marketts-pipeline.md` carries the same
session's backtest-realism detail (instrument economics, bar volume precision,
cost-wiring evidence, operator config, batch runner). This file focuses on the
import pipeline, QuestDB ops, and the quant guardrail.

## The stub incident (why integrity checks matter)

`adapters/driven/acl/providers/markettas_datasource.py` was a hardcoded test
stub: `list_sessions()` returned only `[date(2025, 9, 2)]`, `list_symbols()`
only `["MES", "MNQ"]`, and `load_session()` fabricated 1440 dummy 1m bars.
Every CME import silently ingested invented prices; the suite stayed green
because tests were pinned to the same magic date (stub-contract drift). The
real filesystem datasource was ported back from the deleted notebook version
(git show 70efb24b): day-folder regex discovery (`MarketTaSData_YYYY-MM-DD`),
contract-file matching (`Bests_|TAS_<ROOT> <Mon><YY>[_OHLC].parquet`), schema
normalization, TAS→OHLC derivation when `_OHLC` missing.

Lesson: before trusting any provider that claims to read vendor files, probe
the actual files and compare a fetched sample against raw parquet contents.
A datasource whose docstring says "stub" may still be wired into production.

## Real MarketTaS schemas (verified against live drops)

- Bests: Time, Bid Volume, Bid Price, Ask Price, Ask Volume (~430–490k rows/day);
  older drops use Offer Price/Offer Volume (normalize_bests renames to Ask).
- TAS: Date (%d/%m/%Y), Time (HH.MM.SS.ffffff), Traded Volume, Traded Price, Hit or Take.
- OHLC variant: TAS_<ROOT> <Mon><YY>_OHLC.parquet with Date, Bar Time (HH.MM.SS),
  'Open ' (trailing space!), High, Low, Close, Volume Traded.
- ~202 sessions on disk; symbol mix varies per day (26 lack MES entirely;
  150 MES sessions have native _OHLC, rest derive from TAS).
- Timestamps: Date column drives calendar date (sessions run past midnight UTC);
  naive local combined then treated as UTC downstream.

## Import CLI

```
python -m andromeda import download --config <cfg> --venue cme --pair MES/USD \
  --timeframe 1m --start ... --end ...
--dataset all   # default since 83cec911: bars + book_l2 + trades per invocation
```

- start/end REQUIRED (CLI flags or config.start/end); ISO8601 tz-aware.
- `import up` deliberately REFUSES cme/markettas venues (refuse_cme_import_up).
- Flow: run_download_data → CatalogService.require_from_env().download_bars/download_micro
  → venue-keyed provider registry → QuestDB md_bar/md_l2/md_trade.
- Provider registry keys: bars {synthetic, hl, cme}; book/trades {synthetic, cme} only.
- Backtest reads ONLY QuestDB — nothing auto-imports; ingest is explicit.

## Memory/perf: chunked micro writes (3cb4b4c6)

Multi-month micro windows materialize tens of millions of rows; monolithic
upsert ballooned RSS past 17 GB during the MES import. download_micro now
persists via CatalogService._write_chunked (50k chunks, _WRITE_CHUNK class
attr). Safe because md_* DEDUP UPSERT KEYS make every chunk idempotent.
Verified: re-running a fully imported day (423,691 l2 rows) wrote zero dups.

Provider-side note: providers still return full lists (fetch materializes the
whole window); single-day windows ≈ 500k rows are fine. If multi-month
single-call imports are ever needed again, stream from the provider too.

## QuestDB operations cheat sheet

- PGWire: postgresql://admin:quest@127.0.0.1:8812/qdb (devenv.nix exports
  QUESTDB_PG_URL); CatalogService.require_from_env() reads it.
- NO DELETE FROM; tables partitioned BY DAY (check via tables()).
- Purge = ALTER TABLE md_bar DROP PARTITION LIST '<yyyy-MM-dd>' (full-day
  granularity; used to purge the 1440 fabricated stub bars). A month string
  reports OK but removes nothing — verify with a count after any drop.
- Timestamp predicates need to_str(timestamp, 'yyyy-MM-dd'); date() doesn't exist.
- md_l2 array columns come back from psycopg2 as lists: bid_prices,
  bid_sizes, ask_prices, ask_sizes — take .list.first() for top-of-book.
- md_trade side column is aggressor ('buy'/'sell').
- instrument_id convention: <COIN>-USD-PERP.<VENUE> e.g. MES-USD-PERP.CME
  (nautilus mapping.instrument_id_for_pair; normalize_nt_venue uppercases).
- Dedup keys (schema.sql): md_bar(timestamp,instrument_id,bar_type,source),
  md_l2(...,source), md_trade(...,trade_id) — rewrites/retries are idempotent.

## Long-running batch imports

Single ctx_shell foreground calls die at ~110s; background jobs get killed on
teardown unless detached. Pattern that works:

1. Per-day window script (one CLI invocation per session day) writing JSON
   results to an append-only log — avoids the multi-month OOM entirely and
   gives per-day progress/resume.
2. Spawn via subprocess.Popen([...], start_new_session=True) (setsid) with
   stdout redirected to a log FILE (pipes die with the parent session). Set
   PYTHONPATH=python and QUESTDB_PG_URL explicitly in the child env.
3. Poll progress with grep -c 'exit=0' log; verify completeness by diffing
   distinct md_* day-stamps against the source session folders.

Verification probe pattern: compare SELECT DISTINCT to_str(timestamp,
'yyyy-MM-dd') ... WHERE instrument_id LIKE '%.CME' against the set of session
folders containing that symbol's files; spot-check OHLC values against source
parquet (60/60 exact match verified 2026-08-24).

## Quant research guardrail: lookahead lag-gate

python/andromeda/research/flow_momentum_study.py — a 5m signed aggressor flow
signal on MES showed IC +0.167 (t=22) vs forward 1m returns but was NOT
tradable: entry at signal-bar close +1.05 bp/trade vs next-bar close −0.87 bp;
a 30-second decision lag collapsed it. Same-minute lookahead artifact. The
module ships lag_gate() (same-bar vs next-bar event PnL comparison) as a
mandatory falsification check for any bar-close microstructure edge claim.
Related measurement primitives: signed_flow / flow_signal / zscore_by_day /
pick_events / event_pnl (all pure, synthetic-tested).

Final numbers with the REAL CmeCostModel friction ($0.60 RT micro commission
+ P=0.5 one-tick adverse slip ≈ 0.38 bp of notional; MES notional $32.5k at
6500), 380 non-overlapping events, full imported window:

| hold | entry@decision-close      | entry@next-bar            |
|------|---------------------------|---------------------------|
| 2m   | +2.79 bp/tr, hit 72%     | −0.34 bp/tr, hit 44%     |
| 5m   | +2.56 bp/tr, hit 61%     | −0.63 bp/tr, hit 45%     |
| 10m  | +1.95 bp/tr, hit 61%     | −1.47 bp/tr, hit 46%     |
| 15m  | +1.35 bp/tr, hit 58%     | −1.29 bp/tr, hit 48%     |

Every profitable cell requires filling AT the decision bar's own close; the
production chain carries 10 ms latency + next-bar fills, so all horizons are
negative honestly. Verdict committed a1bdb94a (docstring carries this table).

Methodology notes for reproducing: build price lags c0..cN on md_bar closes,
as-of-join the signal frame on timestamp, pick non-overlapping events
(|z| ≥ threshold, ≥15 min gap), PnL = sign(z) × (exit/entry − 1) × 1e4 − RT.
The apparent +110 ppm t+1 drift after long events is real in-sample but only
capturable from inside the decision bar — that asymmetry IS the diagnosis.

## CME instrument economics regression (2026-08-24)

`crypto_perp_for_pair(venue="cme")` previously built a generic perp:
multiplier=1, price_increment=1e-7, size_increment=0.00001. With sizing in
integer contracts of a $5/point spec this meant: engine PnL understated 5x;
PerContractFeeModel commissions at full USD → fee drag inflated ~5x relative
to true economics; sub-tick fill prices possible that cannot exist on Globex.

Fixed: CME branch now derives instrument fields from CmeContractSpec —
multiplier=Quantity(int(spec.multiplier)), price_increment=tick_size,
size_precision=0/lot=1, price_precision=spec.price_precision (2 for MES).
Nautilus ctor gotchas: multiplier wants a Quantity not Decimal;
base_currency wants Currency.from_str(coin) not str; InstrumentId needs a
Venue object. HL branch untouched. Regression tests in mapping_test.py pin
multiplier/tick/lot/precision and assert the HL path still has multiplier=1.

Meta-rules: when a domain spec object exists alongside an engine instrument,
the instrument must DERIVE from it — duplicated economics drift. Before
trusting any backtest number, confirm fee/fill/latency models are attached at
the add_venue site, not merely defined nearby.

## Micro features for FreqAI on CME (2026-08-24)

Gap: `ensure_micro` had paths for AFML parquet and HL sync but NONE for
venue=cme — a FreqAI AFML backtest on CME data silently ran with EMPTY micro
features (model trading blind, no error raised). Fix shipped in 2cc352f2:

- `adapters/driven/acl/cme/micro_derive.py::derive_cme_micro` — per-minute
  features from md_l2 top-of-book + md_trade flow using AFML bridge alias
  names (`spread_ratio`, `imbalance`, `bid_p/ask_p/bid_q/ask_q`,
  `signed_volume_bar`, `trade_count_bar`, `hit_take_intensity`); crossed/
  degenerate quotes filtered; non-finite values rejected before JSON
  serialization.
- `CatalogService.sync_micro_from_cme` wraps store loads + write; auto-invoked
  by `HistoricalRunnerService.ensure_micro` for venue=cme. Idempotent via
  md_micro dedup keys.
- Operator config `configs/andromeda.freqai-afml.cme.json`.

Traps hit live: store rows are NOT flat — `MdL2Row.bid_prices/bid_sizes/...`
are TUPLES (top-of-book = index 0) and `MdTradeRow` uses `aggressor` (not
`side`). Mock-based tests passed while real rows AttributeError'd; fixed by
verifying against live QuestDB: 423,691 l2 + 251,823 trades → 1,228 feature
bars with sane ranges. Rule: when a strategy consumes OPTIONAL context, assert
the context actually arrived — an empty dict must not pass as success.

## Backtest smoke-test economics check

After instrument+cost fixes, assert per-trade wiring on the result JSON:
`fee_open + fee_close == commission_rt_usd` ($0.60 for micro) and PnL scales
with multiplier × lots. Reference run: 30,850 bars → 15,424 fills, fees
exactly $9,254.40 total. Load perf is NOT a bottleneck: 230k bars load +
convert to NT Bars in ~2.6s; QuestDB EXPLAIN shows DAY-partition pruning +
symbol filter working.
