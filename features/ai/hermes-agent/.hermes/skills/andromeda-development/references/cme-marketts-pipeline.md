# CME / MarketTaS data pipeline & backtest realism (2026-08-24)

Session-specific detail behind the SKILL.md CME sections. Commits: 66e1bd8f,
83cec911, 3cb4b4c6, feb25e91, 6da6eec6, a1bdb94a, bda41ece, 055c2677,
2cc352f2, 3243ef89.

## Import workflow (operator, post-83cec911)

```bash
python -m andromeda import download \
  --config python/andromeda/configs/andromeda.cme.example.json \
  --venue cme --pair MES/USD --timeframe 1m \
  --start <day>T00:00:00+00:00 --end <day>T23:59:59+00:00
# dataset defaults to ALL = bars + book_l2 + trades; per-kind counts under
# results.{bars,book_l2,trades} in the JSON output
```

- `--start/--end` REQUIRED (flag or config.start/end); shipped example configs
  carry neither.
- `markettas_data_root`: CLI flag → `config.markettas_data_root` → default
  `notebooks/data`. Sessions = `MarketTaSData_YYYY-MM-DD/` folders with
  `Bests_<ROOT> <Mon><YY>.parquet`, `TAS_<ROOT> <Mon><YY>.parquet`,
  optional `<...>_OHLC.parquet`.
- Dataset kinds run separately internally: bars → `download_bars`;
  book_l2/trades → `download_micro` (l2 fetch step=1m and trades step=30s are
  ignored — both are event streams). Micro kinds restricted to synthetic|cme.
- Real data shape (2026-08): 202 sessions; MES in ~176 (150 native `_OHLC`
  files, rest TAS-only → OHLC derived from prints). ~430k bests + ~300k TAS
  prints per session. No MES session lacks Bests today.
- Dead ends: `import up` refuses cme/markettas (`refuse_cme_import_up()`);
  `catalog backfill-questdb` is retired.

## Stub lesson (root cause of "import does nothing")

`MarketTaSDataSource` WAS a hardcoded stub on the production path:
`list_sessions()` returned one magic date (2025-09-02), `load_session()`
fabricated 1440 dummy rows, `data_root` ignored. Tests pinned the same fiction
(fixtures created exactly that date/symbols) so the suite was green while
production ingested invented prices. Signature: import "succeeds" instantly
with tiny/zero n_rows; dedup `_existing_bar_ts` drops the fabricated day if
already present. Diagnostics that found it:

1. Read the datasource module itself, not just its callers.
2. Grep tests for magic values shared with production defaults.
3. `git log -S "<string>"` + `git show <old>:<path>` recovers deleted real
   implementations (here: notebooks/markettas/datasource.py @70efb24b) to port
   instead of rewriting.

Fabricated rows already in QuestDB must be purged or they poison backtests forever.

## QuestDB purge / dedup recipes

- NO `DELETE FROM`. Day-scoped purge on DAY-partition tables:
  `ALTER TABLE md_bar DROP PARTITION LIST '2025-09-02'` — the literal must be
  full `yyyy-MM-dd`; a month string reports OK but removes nothing. Always
  verify with a count after dropping.
- Timestamp predicates: `to_str(timestamp, 'yyyy-MM-dd')`; `date()` doesn't exist.
- md_* DEDUP UPSERT KEYS make rewrites idempotent: forced re-download of a
  fully imported day reported n_rows>0 but changed nothing (423,691 rows =
  423,691 distinct timestamps before and after). Retries/gap-fills are safe.
- PGWire: `postgresql://admin:quest@127.0.0.1:8812/qdb` (QUESTDB_PG_URL in
  devenv.nix). instrument_id convention `<BASE>-USD-PERP.<VENUE>`.
- md_l2/md_trade schema traps: l2 price/size columns are ARRAYS
  (`bid_prices[0]` = top-of-book); trade side column is `aggressor`.

## Batch-import runner pattern

Single multi-month windows OOM: providers materialize the whole window AND
`executemany` passes all params in one call (>17 GB RSS observed, zero rows
written). Defense layers:

1. In-repo: `CatalogService._write_chunked` (50k chunks, `_WRITE_CHUNK`);
   dedup keys keep chunks idempotent.
2. Operator: per-day invocations in a loop over session folders containing
   the pair's parquets, appending per-day result lines to a log. ~2 min/day;
   bars dedupe via `_existing_bar_ts` so reruns overlap safely.

Long jobs under ctx_shell: the ~110s foreground cap kills naive invocations;
`nohup ... &` dies with process-group teardown. Reliable launcher:

```python
env = {**os.environ, "PYTHONPATH": "python",
       "QUESTDB_PG_URL": "postgresql://admin:quest@127.0.0.1:8812/qdb"}
subprocess.Popen(["setsid", ".devenv/state/venv/bin/python", "-u", script],
                 stdout=log, stderr=subprocess.STDOUT,
                 cwd=repo_root, env=env, start_new_session=True)
```

Then poll with `sleep ~115s; tail log` cycles, cancelling each auto-backgrounded
shell job. Watch signature of the un-chunked OOM path: 90%+ CPU, growing RSS,
md counts frozen at 0 for minutes.

### Stopping a running batch — kill the DRIVER first (learned 2026-08-25)

The batch loop respawns children: killing the visible
`python -m andromeda import download` leaf just advances the loop to the next
date within seconds (observed live: killed leaf, new child for the following
day appeared immediately). Walk UP from the leaf to the driver, then kill
TOP-DOWN:

```bash
pgrep -af '[a]ndromeda'                      # [x] bracket trick: no self-match
ps -o pid,ppid,lstart,args -p <leaf_pid>     # read PPID + start time
ps -o pid,ppid,lstart,args -p <ppid>         # e.g. python -u /tmp/cme_batch_import.py
kill <driver_pid> <leaf_pid>                 # driver FIRST so nothing respawns
pgrep -af '[a]ndromeda|[c]me_batch'          # verify BOTH patterns gone
```

Drivers may be reparented to PID 1 (long-lived loops started detached) —
PPID=1 does NOT mean orphaned/safe to skip; it IS the process to kill.

Log forensics for resume: `tail /tmp/cme_batch_import.log` — `exit=0` lines
are fully imported days (per-kind row counts follow); `exit=-15` marks a day
killed mid-run (SIGTERM), not a data problem.

### Resuming mid-batch — CME_START_FROM

The loop unconditionally starts at session 1/176. As of 2026-08-25
/tmp/cme_batch_import.py honors an optional `CME_START_FROM=YYYY-MM-DD` env
cutoff applied AFTER MES-day selection (plain ISO string compare):

```bash
CME_START_FROM=2026-02-24 .devenv/state/venv/bin/python -u /tmp/cme_batch_import.py
```

Resume point = the LAST `exit=0` day in the log (redoing the killed `-15` day
is safe — dedup keys make every re-run idempotent). Behavior verified by
slicing the real selection code out of the edited script and exec'ing it
against a temp fixture tree (no-cutoff / resume-mid / early-cutoff cases) —
the throwaway hermes-verify gate pattern; never launch downloads to test the
selector.

## Backtest realism: instrument economics + precision

`crypto_perp_for_pair(venue="cme")` builds from `CmeContractSpec`
(multiplier as Quantity, tick-size increment, size_precision=0/lot=1,
spec.price_precision). Before bda41ece it built a generic perp (multiplier=1,
tick=1e-7, fractional lots): engine PnL understated 5× on MES while
PerContractFeeModel charged full USD commissions → fee drag inflated ~5×,
plus sub-tick fills impossible on Globex.

Precision coupling: NT matching fires "Precision mismatches reached N
consecutive events" when BAR field precision ≠ instrument field precision.
`bar_rows_to_nt_bars` formats volume with `instrument.size_precision` decimals
(was hardcoded `.5f`) and prices with `instrument.price_precision` (MES: 2).
Any new venue instrument must set both precisions consistently with its bar builder.

Cost wiring verified end-to-end: raw_config venue=cme → `resolve_cme_costs`
(micro roots default $0.60 RT, standard $2.20, tick from spec, 10ms latency,
P=0.5 adverse one-tick slip) → `TradeSizing.cme_costs` → `build_backtest_engine`
attaches fee/fill/latency models at add_venue. Sanity number: MES RT friction
≈ $1.225 ≈ 0.38 bp of notional @6500 (1 lot × $5/pt). CME sizing ignores
stake_amount entirely — integer lots, default 1.

Smoke evidence post-fixes: Oct–Nov window clean — 30,850 bars, 15,424 fills,
fees exactly $0.60/trade. Audit rule: assert `fee_open + fee_close ==
commission_rt_usd` on any CME result JSON as the wiring check. Load perf:
230k bars → load_instrument_and_bars in ~2.6s; EXPLAIN shows partition
pruning + symbol filter (not a bottleneck).

## Flow-momentum lookahead study (negative result; keep the gate)

Signal: 5-minute signed aggressor volume z-scored within day. IC vs fwd-1m
return +0.167 (t≈22), monotone quintiles Q1 −39.5ppm → Q5 +40.3ppm/min.

380 non-overlapping |z|≥0.5 events with REAL CmeCostModel friction (0.38bp RT):

| hold | entry@decision-bar close | entry@next-bar |
|------|--------------------------|----------------|
| 2m   | +2.79 bp/tr (72% hit)    | −0.34 bp/tr    |
| 5m   | +2.56 bp/tr              | −0.63 bp/tr    |
| 10m  | +1.95 bp/tr              | −1.47 bp/tr    |
| 15m  | +1.35 bp/tr              | −1.29 bp/tr    |

Every profitable cell requires filling inside the decision bar; a 30-second
signal lag also collapses it. Same-minute lookahead, not alpha. Primitives +
`lag_gate()` live IN-REPO (`research/flow_momentum_study.py`, feb25e91).
RULE: bar-close microstructure signals must show same-bar vs next-bar entry
comparison; only next-bar counts.

## Operator configs & micro derivation

- `configs/andromeda.freqai-afml.cme.json` (3243ef89): FreqaiAfmlStrategy +
  LightGBMClassifier on MES/USD, afml barrier params from HL paper config,
  explicit `cme_costs {enabled:true, lots:1}`.
- `ensure_micro(venue='cme')` auto-invokes `CatalogService.sync_micro_from_cme`
  (2cc352f2): derives per-bar md_micro from imported md_l2 top-of-book +
  md_trade flow using AFML alias names (spread_ratio, imbalance, quote state,
  signed_volume_bar, trade_count_bar, hit_take_intensity). Crossed quotes and
  non-finite values dropped before allow_nan=False serialization. Previously a
  CME FreqAI backtest silently ran with EMPTY micro features.

Full-year backtest once import completes:
```
devenv shell -- python -m andromeda backtest --log-level ERROR \
  --config python/andromeda/configs/andromeda.freqai-afml.cme.json \
  --start ... --end ...
```
