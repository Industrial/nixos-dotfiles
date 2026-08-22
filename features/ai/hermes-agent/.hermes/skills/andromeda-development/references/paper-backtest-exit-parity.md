# Paper vs Backtest Exit Parity (max_holding_bars bug)

Session 2026-08-22. Symptom reported by user: HL paper session opens trades
(e.g. BTC long entered 08:41 UTC) that never close and never appear in
`GET /api/v1/trades` history — while the same strategy closes trades fine in
NT backtest. "It seems to enter trades but it does not exit trades nor log past
trades having happened."

## Root cause

Exit enforcement differs between the two hosts:

| Exit path | NT backtest | PaperPipeline |
|---|---|---|
| stoploss (−5%) | yes | yes (`evaluate_level1_exit`) |
| ROI (+5%) | yes | yes |
| trailing stop | yes | yes |
| custom_exit hook | if defined | `resolve_custom_exit` (FreqaiAfmlStrategy defines none) |
| exit_long/exit_short signal flip | yes | yes (`interpret_signals` last row) |
| AFML time barrier (`max_holding_bars`) | YES (backtest host) | **NO — the gap** |

With entry edge filters suppressing most exit flips and price never moving ±5%,
a paper position lives forever. Expected hold: `max_holding_bars=35` × 1m ≈ 35
minutes; observed: many hours.

Debug order that paid off: enumerate each host's exit SET before doubting
signals. A per-bar trace of `StrategyRunner.populate_entry_exit(store, pair)`
showed `exit_long=1` firing correctly once the model side flipped — signal
generation was fine; enforcement was the gap.

## Fix design

- `evaluate_level1_exit(trade, bar, meta, *, ..., max_hold_minutes: float | None)`
  in `contexts/execution/exits.py`: after trailing/stoploss/ROI checks, force
  `ExitSignal(side=trade.side, tag=EXIT_REASON_MAX_HOLDING)` when
  `(bar.ts - trade.open_ts)` ≥ threshold. `None` keeps legacy behavior.
- New taxonomy constant `EXIT_REASON_MAX_HOLDING = "max_holding"` in
  `adapters/driven/acl/freqtrade/exit_reasons.py`, added to `EXIT_REASONS`.
- Contract tests (RED-first): `contexts/execution/max_holding_exit_test.py` —
  force-close after threshold, no force-close before, legacy None behavior,
  stoploss still wins when earlier.
- Pipeline wiring (COMPLETE + verified 2026-08-22): `PaperPipeline._max_hold_minutes(meta.timeframe)`
  reads `strategy.max_holding_bars.value` × timeframe minutes and passes it as
  `max_hold_minutes=` in `on_bar`'s `evaluate_level1_exit` call. Spy-patch
  (`patch("andromeda.contexts.execution.pipeline.evaluate_level1_exit", side_effect=spy)`)
  confirmed the kwarg reaches the evaluator; flat-model e2e closed the trade at
  exactly open_bar+35 with tag `max_holding`. Full affected suite: 312 passed.
- When adding any future strategy-level exit knob, grep BOTH hosts for its
  enforcement — parity is per-knob, not automatic.

## Deterministic repro harness (no network)

Stub the FreqAI to flip side after N bars and drive SessionRunner directly:

```python
class _FlipFreqai:
    def __init__(self) -> None:
        self.n = 0
    def start(self, dataframe, metadata, strategy_obj):
        out = dataframe.copy()
        out["do_predict"] = 1
        out["&-s_side"] = 1.0 if self.n < 6 else -1.0
        self.n += 1
        return out

strategy = make_strategy(cfg)
strategy.freqai = _FlipFreqai()
pipe = make_pipeline(cfg, strategy, book, PaperExecutionAdapter(),
                     make_strategy_runner(strategy))
state = SessionState(); state.start()          # REQUIRED
sr = SessionRunner(state=state, runner=simulation_runner(pipe), allowed_pairs=None)
store = CandleStore(pair=Pair.parse("SOL/USDT"), timeframe=Timeframe.parse("1m"),
                    max_bars=200, startup_candle_count=1)
for i in range(12):
    store.append(BarRow(ts=base+timedelta(minutes=i), open=o, high=h, low=l, close=c, volume=10.0))
    fill = sr.on_bar(store)
```

Expected result pre-fix: entry fill at first predicted bar, then fills=None
forever while `exit_long=1` — reproduces production exactly.

API gotchas that cost debug cycles (all hit this session):
- `SessionRunner` is keyword-only: `state=`, `runner=`, `allowed_pairs=` — NOT positional cfg.
- `SessionState` must be `.start()`ed or `on_bar` raises
  `BotControlError("cannot on_bar while session is stopped")`.
- Shorts require `"trading_mode": "futures"` in the RunConfig raw dict —
  `make_pipeline` reads `cfg.trading_mode` and has NO trading_mode kwarg;
  otherwise `KernelError: shorts require trading_mode=futures`.
- `CandleStore` has no `capacity` kwarg — use `max_bars=`; pair/timeframe are
  Pair/Timeframe VOs.
- `Trade` construction: `stake=StakeAmount.parse(...)`, no `is_open`/`amount`
  kwargs — openness derives from `close_ts is None`.
- `StrategyMetadata` requires `timeframe`, `startup_candle_count`,
  `can_short` explicitly in tests.

## Scaling the paper config to 50 pairs (same session)

- `pairlist` + `instruments` 10→50 entries, `max_open_trades` 10→50.
- Wallet sizing rule: `dry_run_wallet ≥ stake_amount × max_open_trades +
  headroom` ⇒ 25k → 100k for 1000 × 50.
- Warmup budget before judging behavior = `train_period_candles × timeframe`
  (175 × 1m ≈ 3 h). User protocol: hard timeout at warmup length, then poll
  every 10 min and report phase/counters from the run dir + API.
- Not all configured pairs exist on HL: several (BONK, PEPE, GRT, MANA, …)
  fail subscription with "instrument not found in cache" and never warm up.
  Prune dead pairs from the pairlist once warmup coverage is known — they
  otherwise sit in `pending_micro` forever and pollute the warm gate.
- Launching requires `QUESTDB_PG_URL=postgresql://admin:quest@127.0.0.1:8812/qdb`
  in the process env or the session thread dies instantly
  (`CatalogError: QUESTDB_PG_URL is not set` from `build_hl_paper_live_node`).
  The HTTP server still binds, so the API answering is NOT proof the session
  is alive — check the run log for the session-start line.
- Watchdog pattern that worked: background terminal with notify_on_complete +
  a cron job polling status.json/count/profit every 10 min; CLI sessions have
  no live delivery channel, so reports land in cronjob list output unless
  deliver targets a gateway platform.

## Ops lesson: verify persistence, don't trust uptime (same session)

A bot ran 16+ hours with `QUESTDB_PG_URL` set in its environ while EVERY
`md_*` table held 0 rows. Two checks that catch this:

1. Count rows over PGWire directly (host port map observed: 8812 PGWire OPEN,
   9000 QuestDB HTTP CLOSED, 9009 OPEN):

```python
from andromeda.contexts.catalog.adapters.questdb.client import QuestDbClient
client = QuestDbClient.from_env()   # postgresql://admin:quest@127.0.0.1:8812/qdb
with client.connect() as conn, conn.cursor() as cur:
    cur.execute("SELECT table_name FROM tables()")
    for t in (r[0] for r in cur.fetchall()):
        cur.execute(f"SELECT count(*) FROM {t}")
        print(t, cur.fetchone()[0])
```

2. Map the process's REAL sockets instead of trusting env vars: match
   `/proc/<pid>/fd/*` symlink inodes against `/proc/net/tcp` entries. The stale
   bot had exactly one remote peer (an HTTPS endpoint) and ZERO PGWire
   connections despite `QUESTDB_PG_URL` in its environ.
