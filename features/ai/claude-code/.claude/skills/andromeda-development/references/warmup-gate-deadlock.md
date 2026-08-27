# Warmup-Gate Deadlock: One Dead Pair Bricks the Whole Session

Session of 2026-08-22. 50-pair HL paper session (`andromeda.freqai-afml.hl.paper.json`),
launched 16:00 UTC. User asked at ~21:45 UTC "are models training? should be every minute?"

## Answer: zero training, and none possible

- `grep -c 'FreqAIHost.train' run.log` → **0**
- `grep -c 'freqai.start' run.log` → **0** (adapter never invoked once)
- `grep -c 'forward tick' run.log` → **0** (trading loop never entered)
- `grep -c 'forward collecting' run.log` → 2290+ (warmup snapshots only)

## Root cause: the gate is a conjunction over ALL pairs

`python/andromeda/contexts/session/forward_session.py` (on_ws_tick, ~L129–170):

```python
pending = [
    item for item in universe
    if not _micro_covers_train(micros[item], needed=needed)
]
ready = iteration >= needed and not pending
if not ready:
    return self._warming_snapshot(...)
return self._forward_tick(...)   # trading + freqai.start live here
```

`_micro_covers_train` returns False when `stats.get("pending")` is set or
`n_rows < needed`. Five pairs could never produce micro rows:

| Pair | Failure mode | Evidence |
|---|---|---|
| BONK, GRT, MANA, PEPE | instrument unlistable: `instrument not found in cache: X-USD-PERP.HYPERLIQUID` ×7 each | 0 rows in every md_* table |
| MKR | context-feed gap: md_l2 flows (1,884 rows to 18:48) but md_mark/md_index stopped 16:00:30 | "hl micro empty" ×1888; build_hl_micro_frame requires Depth10+mark+index per bar close |

→ `pending` never empty → `ready` never true → `_forward_tick` unreachable
forever. The iteration counter (`iter=2286/175`) is irrelevant — it's one
conjunct of two.

## The red herring that cost a debug cycle

`run.log` shows ticking lines like:

```
populate_indicators pair=BTC/USDT bars=213
```

These are NOT the trading loop. They come from FreqUI/chart HTTP RPCs —
`adapters/driving/http/pair_ohlcv.py` (`StrategyRunner.populate_entry_exit`)
and `analysis_rpc.py` — i.e., request-driven chart rendering. Their pair mix
follows browser activity: 38 distinct pairs during hour 19, collapsing to
DYDX-only then BTC-only later. Easy to misread as strategy liveness; check the
source before treating them as loop progress.

## Diagnostic sequence for "training looks missing"

1. `grep -c 'forward tick' run.log` — 0 ⇒ never left warmup; stop here.
2. Tail the latest `forward collecting ... pending_micro=[...]` line — dead
   pairs persist there forever.
3. Per-instrument ground truth in QuestDB:
   ```sql
   SELECT instrument_id,
          count(*) FILTER (WHERE table = 'md_bar') ...
   -- or per table:
   SELECT min(timestamp), max(timestamp), count(*)
   FROM md_mark WHERE instrument_id = 'MKR-USD-PERP.HYPERLIQUID';
   ```
   The feed with the earliest max(timestamp) is the culprit (MKR's mark/index
   died ~15 min after start while L2 kept flowing).
4. Only after ruling out the gate should you suspect adapter wiring/attach.

## Fix options — APPLIED 2026-08-22 (same day, later session)

- Config-level: DONE — pruned BONK/GRT/MANA/PEPE/MKR from `pairlist` +
  `instruments` and switched quote to USDC (45 pairs). Config validator
  (`andromeda/configs/validate_paper_config.py`) now guards against
  known-dead bases, orphan instruments, and quote drift.
- Code-level: DONE — `forward_session._excluded_pairs()` excludes pairs with
  zero micro rows after a 45-min grace; gate runs over active pairs only.
  `_warming_metrics()` emits ready/active/total/warmup_pct into every
  warming snapshot + log line (replaces the meaningless iter/N form).
  Staleness: `sync_catalog_micro_from_hl` stats carry `last_row_age_min`
  + `stale` so MKR-style feed death is visible in one tick.
- Contract tests: `contexts/session/partial_failure_test.py`,
  `configs/validate_paper_config_test.py`. Full sweep: 322 passed.
- The "log once per dead pair" suggestion is still open (nice-to-have;
  the exclusion list in telemetry covers the operator need).

## Related gotchas observed same session

- Bars are not purely websocket-fed: candle stores periodically bulk-refill
  from QuestDB history (BTC store jumped 162→213 bars between 20:41 and
  21:32). Don't compute warmup ETA from 1 bar/min alone.
- Tick snapshots key iteration as `iteration`; the final result dict uses
  `iterations` (plural) — grep accordingly.
- Stale SIGTERM notices from killed bots replay OLD crash tracebacks hours
  later; always verify which pid is alive and read the newest run dir before
  diagnosing.
