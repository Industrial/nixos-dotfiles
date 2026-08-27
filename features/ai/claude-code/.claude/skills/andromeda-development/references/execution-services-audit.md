# Execution services audit (2026-08-24 session)

Context: user asked which files under `python/andromeda/services/execution/`
are not actually ExecutionService classes, then asked for the WHERE/HOW/WHEN
rationale of the three service hierarchies and whether the "paper pipeline"
and "backtest service" are still needed.

## The three contracts (verified against source)

| Contract | Question | Members | Subclass rule |
|---|---|---|---|
| `services/venue/venue_service.py::VenueService` | WHERE do we trade? | key registry/normalize, `list_pairs`, `executor_kind`, dry-run guard; only `cost_model()` abstract | one subclass per venue (hyperliquid, cme, ibkr, paper); composition picks via `providers.Selector` on canonical venue key |
| `services/execution/execution_service.py::ExecutionService` | HOW do fills happen? | `on_bar`, `submit`, `snapshot_trades`, abstract `dry_run` property | subclasses are AXIS kinds: `SyntheticExecutionService` (backtest, always dry), `RealExecutionService` (forward; paper fills while dry_run else injected VenueExecutor), `HyperliquidRealExecutionService` |
| `services/runner/runner_service.py::RunnerService` | WHEN/HOW does the session run? | lifecycle FSM verbs (`start/pause/resume/stop/apply_action`), `snapshot`, gated `on_bar` | Live vs Historical differ structurally. `LiveRunnerService` has NO subclasses by design: execution variance via injected ExecutionService, feed variance via `configure_loop` |

Doctrine: subclass only for structural variance; inject everything else.

## services/execution inventory (14 files)

Actual service hierarchy (keep):
- `execution_service.py` — ABC (L24)
- `synthetic_execution_service.py` — wraps PaperPipeline entirely; `dry_run=True` always
- `real_execution_service.py` — pipeline for bars + paper/live submit routing
- `hyperliquid_real_execution_service.py` — HL venue kind of real axis

Squatters (not services):
1. `paper_pipeline_service.py` — `PaperPipeline` (L69-371) + factory
   `build_paper_pipeline()` (L39). This IS the bar engine: pending entry/exit
   parking (`_should_park_entry/_should_park_exit`), position adjustment,
   unfilledtimeout, strategy-hook vetoes (confirm_trade_entry/exit,
   custom_stoploss/custom_exit). Both axes depend on it: Synthetic wraps it
   entirely; Real drives it per-bar while routing submits elsewhere;
   LiveRunnerService holds one. ARCHITECTURE.md L78 already calls it "engine
   math; services orchestrate" — but it orchestrates nothing, so the
   `_service` suffix is wrong.
2. `paper_execution_service.py` — `PaperExecutionAdapter`
   (@dataclass(slots=True), L26) implements the VenueExecutor driven port
   (fills at intent rate, optional gated cost model via `_fee_rate` helper).
   All four venue adapters (hl/orders.py, hl/hyperliquid_venue.py, cme, ibkr)
   fall back to it when dry-running — adapter-layer code living in services/.
3. `backtest_service.py` — `BacktestResult` (frozen dataclass, L30) +
   `run_paper_backtest()` (L41). Docstring admits: "Paper backtest test-double
   (not operator SoT — use engine.nt_backtest)". Caller census:
   - Production callers of `run_paper_backtest`: exactly ONE —
     `test/proofs/unified_executor_parity_test.py`.
   - All other importers take only `BacktestResult` into test files
     (loss_composite_test, paper_session_test, ft_17_59_hyperopt_loss_test,
     hl_paper_model_cache_parity_test).
   It also duplicates composition: hand-builds pipeline + Synthetic wrapper
   instead of using `make_pipeline` + ExecutionContainer.

## Verdicts given to the user

- backtest_service: DELETE from services/. Real backtest host is NautilusTrader
  (adapters/driven/acl/nautilus/{nt_backtest,nt_compose,strategy_adapter}.py).
  Move run_paper_backtest+BacktestResult to test-proof support beside
  test/proofs/ (the parity proof legitimately needs an FT-host harness).
- paper pipeline: KEEP but rehome/rename — it is load-bearing engine math for
  both axes, not a service. Drop `_service` suffix (e.g. paper_engine.py /
  PaperEngine) or move under adapters/driven/acl/freqtrade/ (FT-bridge
  machinery).
- PaperExecutionAdapter: move beside the VenueExecutor port in the adapter
  layer.
- Consolidate duplicated factories: `build_paper_pipeline` vs
  `composition/factories/makers.py::make_pipeline` (L88-112).

## Agreed step plan (user asked "what would you do?", not yet executed)

1. Move run_paper_backtest/BacktestResult out of services into test-proof
   support; update 5 importing test files; delete backtest_service.py.
2. Rename/rehome engine without `_service` suffix; consolidate the two
   pipeline factories into one.
3. Move PaperExecutionAdapter to adapter layer beside VenueExecutor port.
4. Update ARCHITECTURE.md concern table (execution area, L70-89); tests move
   with subjects to hold the 95% coverage line.

Net result: services/execution/ = ExecutionService + axis/venue subclasses
only — mirroring services/runner/ and services/venue/, and matching what
`__init__.py` already promises ("re-exports the four service names").
