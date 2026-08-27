# Dual-runner split-brain: exits fired, trades never saved (2026-08-23)

Session: run `2026-08-23_08-42-45_andromeda.strategies.freqai_afml_freqaiafmlstrategy`
(PID 3632847, `andromeda up --config andromeda.freqai-afml.hl.paper.json`, port 8080).
Operator report: BTC/USDC afml_long "opened 14:19 @77532" later gone from FreqUI;
question was why it was not closed and not saved.

## Root cause (proven against the live composition graph)

`composition/containers/session_container.py` wires `runner_service`
(`providers.Factory(ForwardRunnerService, ..., pipeline=pipeline)`) into TWO
consumers: `session_runner = make_session_gate(runner=runner_service)` AND
`forward_session = make_forward_session(runner=runner_service)`. dependency_injector
Factories resolve PER CONSUMER, so:

```
forward_session.runner is session_runner.runner : False   # two ForwardRunnerService
fwd.runner.pipeline is gate.runner.pipeline     : False   # two PaperPipeline
pipeline_a.book is pipeline_b.book              : True    # ONE shared OpenTrades (Singleton)
forward_session.pipeline.on_trade_closed : <list.append>  # journal wired HERE
gate.runner.pipeline.on_trade_closed      : None           # but ticks drive THIS one
```

Tick path: `run_paper_loop → _paper_ws_tick → ForwardSessionService._forward_tick →
session_runner.on_bar(store) → runner(B).on_closed_bar → pipeline(B).on_bar`.
Exit path inside `PaperPipeline._complete_exit`: `book.apply_exit(...)` removes the
trade from the SHARED book, then fires `self.on_trade_closed(closed)` — which is None
on B. The journaling callback (`ForwardSessionService.__post_init__:
pipeline.on_trade_closed = self.runner.closed_trades.append`) landed on the idle
pipeline A. Result: every exit evicted the trade with zero record anywhere —
`/api/v1/trades` empty all day, `n_closed=0` in every snapshot heartbeat, UI book
wholesale-cleared+refilled every ~2 min by `apply_session_snapshot` (so vanished
trades never even lingered in FreqUI).

## Timeline reconstruction (rows.jsonl + heartbeat greps; UTC; host local = UTC+2)

| UTC | local | event |
|---|---|---|
| 08:42:45 | 10:42 | process + run dir start; engine warming, publishes empty snapshots (`n_bars=0`) every ~2 min for ~5h |
| 13:44:37 | 15:44 | first real tick iter=175: bars 0→890 bulk refill; n_open=1 appears instantly (catch-up entry over backfilled bars) |
| 14:22:52 | 16:22 | iter=194 → operator's trade ENTERS on lagged bar ts 14:19:00Z @77532 (FreqUI showed that bar time as "open date") |
| 14:46:21 | 16:47 | iter=205 → n_trades 1→0: trade EXITED in-engine (~24 min ≈ level-1/time-barrier exit), never journaled |
| 15:23→16:04 | … | cycle repeats: entries at iters 206/223/240, each silently discarded on exit |

Key misdirections to avoid next time:

- The FreqUI open date (14:19 local-looking) matched a window where heartbeats said
  n_open=0 — because the date is the SIGNAL-BAR timestamp, not wall-clock. Convert
  timezones before correlating.
- `ps aux | grep -iE "freqtrade|paper|andromeda"` firewalled output hid nothing here:
  exactly one process existed. Verify with a file-dump (`ps ... > /tmp/f && read f`)
  when archives truncate.
- The tiny `*_andromeda` run dirs appearing every few minutes are chart-RPC stubs,
  not restart churn of the trading session (live dir has full meta/log/journal).

## Fix options

1. Promote the shared runner to Singleton: `runner_service =
   providers.Singleton(ForwardRunnerService, mode=..., pipeline=pipeline)` —
   smallest diff; both consumers then share one instance and one callback wiring.
2. Or wire the callback through the driven instance: have ForwardSessionService set
   `session_runner.runner.pipeline.on_trade_closed` instead of its own injected
   runner's pipeline.
Either way add an identity test per the house singleton rule:

```python
def test_forward_session_shares_runner_with_session_gate():
    c = create_container(cfg_path)
    fwd = c.forward_session()
    assert fwd.session_runner.runner is fwd.runner
    assert fwd.session_runner.runner.pipeline.on_trade_closed is not None
```

## Resolution (shipped 2026-08-23, same day)

The concurrent session-dissolution refactor landed the right shape mid-session;
this session finished it. Final wiring in `session_container.py`:

```python
runner = providers.Selector(
    providers.Callable(runner_mode, run_config),
    simulation=providers.Singleton(ForwardRunnerService, mode="simulation",
                                   pipeline=pipeline, state=session_state),
    real=providers.Singleton(ForwardRunnerService, mode="real", ...),
)
session_service = runner   # legacy alias — all three resolve the SAME singleton
session_runner  = runner
runner_service  = runner

forward_session = providers.Factory(make_forward_session, cfg=run_config,
    catalog=data_catalog, runner=runner, candles=candle_service,
    sessions=runner, ...)   # sessions=runner: auto-start uses the singleton too
```

Supporting edits: `ForwardSessionService` dropped its duplicate `session_runner`
field (single injected `runner`); `make_forward_session(cfg, catalog, runner, *,
candles, sessions, ...)` lost the dead positional; `SessionService` was dissolved
into `RunnerService` (lifecycle verbs + `ensure_started` now live on the runner,
so CLI calls `container.session_runner().ensure_started()`, not a separate
service). TDD suite locking the contract:
`composition/forward_session_trade_persistence_test.py` — C1 one-runner-per-
process across every provider alias (`session_service()` is
`runner_service()` is `session.session_service()`), C2 forward session drives
that exact runner and `on_trade_closed.__self__ is runner.closed_trades`,
C3 full open→exit cycle through `forward.on_ws_tick` keeps the closed trade in
`runner.closed_trades` AND publishing in snapshot rows.

TDD gotchas hit while writing it:
- `list.append` creates a fresh bound method per attribute access — assert
  `callback.__self__ is the_list`, never `is` between two `.append` reads.
- The deterministic loop needs BOTH `use_synthetic_bars=True` (else the tick
  path QuestDB-refills an empty store and never reaches the strategy) and the
  FSM started (`make_forward_session(sessions=...)` does it via auto-start).
- `providers.Selector(Singleton)` aliases share one instance, but a Factory
  dependency consumed twice does not — the identity test is the only proof.
- When finishing someone else's half-staged refactor, re-read every touched
  file first; their edits changed this container twice DURING the fix.

## Diagnostic playbook (generalizes)

1. Live API truth first: `/status` vs `/trades`; note whether closed-trades count
   EVER moves. `n_closed=0` forever while trades cycle = bookkeeping disconnect,
   not strategy behavior.
2. Reconstruct from `decisions/rows.jsonl`: print rows where `(n_trades, n_bars>0)`
   changes → entry tick / exit tick with ts+iter.
3. Grep run.log for `session snapshot` transitions and `n_open=1` first-ever line.
4. Probe composition identity directly (throwaway script under /tmp, run with
   `.devenv/state/venv/bin/python`): compare `is` on runner/pipeline across
   consumers; check where callbacks were bound.
5. Only then read code — with the graph facts in hand the wiring bug is visible in
   minutes instead of hours.
