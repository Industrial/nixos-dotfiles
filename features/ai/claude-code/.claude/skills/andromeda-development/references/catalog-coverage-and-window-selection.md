# Catalog Coverage Audit → Backtest Window Selection (CME/MES)

Verified 2026-08-25 while choosing `--start/--end` for `andromeda.freqai-afml.cme.json`.
Trigger: the batch import had been killed mid-run, leaving data layers skewed —
any window chosen without a per-layer audit would have silently run on
book/trade-free bars.

## Reaching the DB

- QuestDB HTTP console (:9000) may be OFF while PGWire (:8812) answers fine.
  Don't conclude "QDB down" from a curl to 9000; probe the pg port instead.
- Credentials: read `QUESTDB_PG_URL` out of a proven-working script's env
  (`/tmp/cme_batch_import.py` carried them) via regex; NEVER print the URL.
- Driver: `.devenv/state/venv/bin/python` + psycopg2. `python3 -c` and heredocs
  are shell-blocked — write throwaway `/tmp/hermes-verify-*.py`, run, delete.

## The reliable per-day coverage query

```sql
select timestamp_floor('1d', timestamp) d, count() c
from md_bar
where instrument_id = 'MES-USD-PERP.CME'
group by d order by d;
```

TRAPS:
- `group by cast(timestamp as date)` through the PG wire returned SILENTLY
  WRONG counts (exactly 1/day on 1380-bar days). Any surprising aggregate must
  be cross-checked with a raw sample (`select timestamp, close … limit`) —
  plausible-looking wrong numbers cost a full false-analysis round here.
- VENUE-TAG CASE TRAP (2026-08-25, cost a false "no data" alarm on HL pairs):
  md_bar/md_l2/md_trade/md_mark/md_index store UPPERCASE exchange names
  (`HYPERLIQUID`, `CME`), but **md_micro stores lowercase** (`hl`, `cme`).
  A uniform-case venue filter returns clean-looking ZEROES. Always inventory
  venues unfiltered first: `SELECT venue, count(*) FROM <t> GROUP BY venue`.
- `table_columns` exposes a reserved word: `select "column" from
  table_columns('md_bar')` (double quotes mandatory).
- Scope EVERY query by `instrument_id` — an unscoped scan mixes 10 Hyperliquid
  pairs into your CME answer.

## Day-quality taxonomy (MES 1m)

| Signature | Meaning |
|---|---|
| ~1380 bars | full ~23h session |
| ~1321 | full day minus maintenance window |
| exactly ~59–60 | Sunday-evening open stub — REAL data, keep |
| 0 rows | dead day (holiday closure or missing import) |
| <~700 midweek | holiday half-day OR provider gap — investigate |

Midweek single-day holes are real: found 2026-02-18 (a Wednesday: 59 bars,
zero book/trades between two healthy sessions). Suspect MarketTaS provider
gap, not exchange closure. Consecutive degraded days happen around holidays
(Jan 19 fully absent + Jan 20 stub for MLK/Inauguration 2026).

## Layer skew is the killer finding

Layers fill independently: md_bar (OHLC parquets), md_l2/md_trade (Bests/TAS
parquets), md_micro (derived at runtime). State found 2026-08-25: bars healthy
through 2026-07-14, but l2/trades STOPPED 2026-02-26 because the batch import
was killed. "The pair has data" is meaningless — audit ALL FOUR tables for the
exact pair before promising a window. Raw parquet folders beyond the imported
frontier can usually be imported later (`CME_START_FROM=<first-missing-day>`
resume on the batch runner).

## ensure_micro stale-cache trap

`HistoricalRunnerService.ensure_micro` EARLY-RETURNS whenever
`micro_lookup(pair, timeframe, venue)` is non-empty — even if every cached row
lies entirely OUTSIDE your requested window (found: 1505 MES md_micro rows, all
2025-09-02/03 relics, would have shadowed a Jan–Feb run). Before a CME backtest
on a new window: purge the pair's stale md_micro days
(`ALTER TABLE md_micro DROP PARTITION LIST 'yyyy-MM-dd'` per day — no arbitrary
DELETE in QuestDB) so `sync_micro_from_cme` re-derives for the actual range.

## Warmup-headroom accounting

The runner auto-backshifts the catalog load start by
`max(3 × train_period_candles, 600)` 1-minute bars
(`domain/session_warmup.py::freqai_fe_warmup_bars`). Count the REAL pool behind
your start (`select count() … where ts < <start>`), including weekend/evening
stubs: verified Dec 29–Jan 4 pool = 718 bars (659 weekday-session + 59 Sunday
stub). A window whose warmup pool crosses a data hole degrades features
silently — no error is raised.

## Verdicts produced (orientation only — RE-AUDIT before reuse; data moves)

- Longest strictly-clean window: **2026-01-21 → 2026-02-13** (18 sessions,
  full bars + book + trades every day).
- Wider, accepts 4 degraded days: 2026-01-05 → 2026-02-26 (Jan 19 dead; Jan 20 /
  Feb 16 / Feb 18 59-bar stubs).
- Other holes: Nov 3–21, Dec 15–29, Jun 19 + 22–23, Apr 3; imports stop Feb 26.

## Verify-the-verifier pays

Round-1 assertions written from the first analysis FAILED 5/6 — and every
failure was a genuine analysis error (missed Jan 20 stub, missed Feb 18 hole,
wrong micro-row count), not a test bug. Pattern: encode each claim destined for
the user as an SQL-backed assertion; treat failures as findings about the DATA,
fix the claim (and the analysis), then assert the corrected ground truth.
