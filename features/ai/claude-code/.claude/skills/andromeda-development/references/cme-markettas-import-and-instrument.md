# CME / MarketTaS Data Path — Import, Instrument Economics, Backtest Wiring

Session-proven facts (2026-08-24/25, MES full-history import + first real
backtest). All paths relative to repo root.

## 1. Import flow (operator surface)

```
python -m andromeda import download --config <cfg.json> \
  [--venue cme] [--pair MES/USD] [--timeframe 1m] \
  --start <ISO> --end <ISO>            # required unless in config
```

- `--dataset` defaults to **all** (bars + book_l2 + trades in one run);
  result JSON reports per-kind counts under `results`. Micro kinds require
  venue synthetic|cme.
- Venue `cme` selects CmeBarsProvider / CmeBookProvider / CmeTradesProvider
  (`adapters/driven/acl/providers/cme.py`). `import up` REFUSES cme/markettas
  by design (`refuse_cme_import_up`) — always use `import download`.
- `markettas_data_root` resolution: flag → config key → `notebooks/data`.
- Bars land in QuestDB `md_bar` keyed `MES-USD-PERP.CME`; book → `md_l2`,
  trades → `md_trade`. `--catalog` value is vestigial in this path.

## 2. MarketTaSDataSource is REAL now (was a fabricating stub)

Until 2026-08-24 `markettas_datasource.py` was a hardcoded test stub:
one magic session (2025-09-02), dummy frames, `FileNotFoundError` otherwise.
Every prior CME import ingested invented prices; re-runs looked like
"does nothing" because dedup dropped the already-written fake day.

Real implementation (ported from deleted notebook version):
- Discovers `MarketTaSData_YYYY-MM-DD` dirs under data_root (regex).
- Contract files matched by `^(?:Bests|TAS)_(ROOT)\s+(Mon)(YY)(_OHLC)?\.parquet$`.
- Normalization: `Offer Price/Volume` → Ask; OHLC column `"Open "` (trailing
  space) renamed; timestamps assembled from `Date` (d/m/Y) + `Time`
  (HH.MM.SS.micro); all-null quote rows dropped; TAS→OHLC 1m derivation when
  no `_OHLC` parquet exists.
- `load_session` requires Bests + (TAS or OHLC); callers swallow
  FileNotFoundError → sessions missing files silently skipped (by design).

## 3. Memory: chunked micro writes

Multi-month book_l2 windows materialize tens of millions of rows; a single
monolithic upsert ballooned RSS past 17 GB. `CatalogService.download_micro`
now persists via `_write_chunked` (50k rows/chunk). Safe because md_* DEDUP
keys make every chunk idempotent. If you raise window sizes anywhere else,
chunk the writes too.

## 4. CME instrument economics (correctness-critical)

`crypto_perp_for_pair(..., venue="cme")` builds the instrument from
`CmeContractSpec`: multiplier ($/point, MES=5), tick_size increment (0.25),
integer lots (size_precision=0), price_precision=2. Before the fix it was a
generic perp (multiplier=1, tick 1e-7, fractional size):

- Engine PnL understated 5x on MES while PerContractFeeModel charged full USD
  commissions → fee drag appeared 5x overweighted.
- Sub-tick fill prices impossible on Globex were accepted.

Regression tests pin multiplier/tick/precision in `mapping_test.py`.

## 5. Bar volume precision must follow the instrument

`bar_rows_to_nt_bars` formats volume to `instrument.size_precision` decimals.
Hardcoded 5-dp volume + size_precision=0 instrument triggers NT matching
engine "Precision mismatches reached 20 consecutive events" errors. Symptom
signature: ERROR spam early in backtest, fills degrade.

## 6. Cost model wiring (verified end-to-end)

Config → `resolve_cme_costs` (micro roots default $0.60 RT, standard $2.20;
slippage_prob 0.5 = P(one adverse tick) on market fills; latency 10 ms) →
`resolve_trade_sizing.cme_costs` → `build_backtest_engine` attaches
FixedFee/PerContractFee + ProbabilisticFill + StaticLatency models. Sanity:
$0.60 RT ≈ 0.38 bp of MES notional at 6500 × 1 lot. Result JSON fees should
equal commission_rt_usd per trade exactly — check that when auditing.

## 7. QuestDB purge / idempotency ops

- No DELETE in QuestDB. Purge a bad day: `ALTER TABLE md_bar DROP PARTITION
  LIST '2025-09-02'` (DAY partitions; month strings rejected).
- md_l2 / md_trade DEDUP keys make re-imports idempotent — verify with
  `count(*) == count(DISTINCT timestamp)` for the day, NOT total-table deltas
  while the batch importer runs concurrently (race gives false violations).
- Query plans already prune partitions + filter symbol; loading 230k bars ≈
  2.6 s including NT conversion — loading is not the bottleneck.

## 8. Batch import pattern (long-running)

Per-day subprocess loop (each day = own `import download` invocation):
- Detach with `setsid` + `start_new_session=True`, unique /tmp log; plain
  nohup children get killed when the tool session tears down.
- ~2 min/session (≈430k bests + ≈300k tas rows). Verify completeness with a
  script comparing session dirs vs `SELECT DISTINCT to_str(timestamp,
  'yyyy-MM-dd') FROM md_* WHERE instrument_id LIKE '%.CME'`.

## 9. Flow-momentum research verdict (do not relitigate without new data)

5-min signed aggressor volume: IC +0.167 vs fwd 1m (t=22) BUT event study
under real costs shows every profitable cell requires filling AT the decision
bar close; next-bar entry negative at all horizons. Same-minute lookahead.
Falsification machinery lives in `research/flow_momentum_study.py::lag_gate`;
any new bar-close microstructure edge claim must pass it.
