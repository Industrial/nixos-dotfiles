# DI Instantiation Audit — 2026-08-24

Session ledger for the "all services via DI, only as many instances as needed"
pass. Companion to the Multi-consumer provider audit section in SKILL.md.

## Method

1. Enumerate services: glob `services/**/*_service.py` (18 files at audit time).
2. Find bypasses: regex `\b(PairlistService|CandleService|CatalogService|...)\s*\(`
   over `python/`, subtract `composition/` and `*_test.py`.
3. Graph check: for each provider in `composition/containers/*.py`, list its
   consumers; any provider with ≥2 consumers must resolve to ONE instance
   (Singleton arms inside Selectors count).

## Fixed

| Site | Change |
|---|---|
| execution_container `venue_executor` | Factory arms → Singleton arms (2 consumers) |
| execution_container `strategy` | Factory → Singleton (2 consumers) |
| makers.make_execution_service | `executor=` now passed to RealExecutionService (was dropped) |
| domain/paper_engine.build_paper_engine | `strategy_service` required positional; internal StrategyService/_instantiate_strategy removed |
| 33 caller files | 71 callsites rewritten to `strategy_service=StrategyService(strategy=...)`; imports added; 34 files py_compile green |
| http/app.py | `_host()` documented as memoized fallback; for_tests job-host defaults kept w/ justification comment |
| http/analysis_rpc.py | run_lookahead/run_recursive take `strategy_service=`; AnalysisJobHost carries + forwards it |
| application_container | `historical_runner = Singleton(HistoricalRunnerService)`; analysis_host wired `execution.strategy_service`; backtest_host wired `runner=historical_runner` |
| http/backtest_rpc.py | BacktestJobHost.runner field; `_run` uses injected else local |
| http/pair_ohlcv.py | pair_history_body/_analyze_catalog_frame take `strategy_service=` |
| http/pairlists_rpc.py | PairlistEvalHost.pairlist_service None-default + memoized `_service()` (was `default_factory=PairlistService`) |
| cli/app.py | backtest/freqai-train/freqai-predict/freqai-materialize-wf resolve via `create_container()` providers |
| nautilus/paper_session.py | catchup runner + catalog hoisted out of per-pair loop |

## UNFINISHED — next session starts here

1. paper_session.py catchup: `catalog_service = _catalog_or_memory()` assigned
   but the loop still calls `_catalog_or_memory()` inline for micro lookup →
   ruff F841. Use the variable or delete it.
2. NO pytest/ruff run yet (only py_compile). Run scoped suite. Expected fallout:
   application_test provider-kind assertions; app_main_test `_Container` doubles
   (freqai commands now touch create_container + container.freqai_service()/
   historical_runner()); pairlists_rpc tests asserting dataclass field equality.
3. Identity tests owed (§5 rule): historical_runner, venue_executor, strategy
   singletons — assert two resolutions return same object.
4. Coverage gate 95% must stay green.

## Remaining known bypasses (deliberately deferred)

- FreqaiService static helpers self-instantiate: `tabular_vs_sequence_parity`
  (~L647), `_predict_segment` (~L771 — runs under joblib workers; needs config
  threading, NOT a singleton), `run_adaptive_backtest` inner (~L1158).
- `NtFreqAIStart.__post_init__` builds `FreqaiService(config=self.config)`.
- `nt_compose.prepare_artifacts` + `artifacts/materialize.materialize_indicators`
  build bare `FreqaiService()` (materialize defers the import to dodge a cycle).
- `cme/costs.resolve_cme_costs` builds CME venue service per call.
- `import_daemon/enqueue.expand_universe_jobs` builds HyperliquidVenueService().
- `CatalogService.require_from_env()` env-scoped resolution inside
  services/adapters — a design question (env fallback vs injection), separate
  decision before touching.

## Tooling notes

- lean-ctx ctx_search regex: no lookaround — use `\b` word boundaries.
- ctx_patch: `replace_symbol` may demand `line`; `op=replace_unique` works
  without anchors. READ THE EVIDENCE DIFF: a `-6` line delta when you intended
  ±0 means the patch truncated following code (happened in routes.py;
  repaired by re-inserting the lost body and confirming hash matched preimage).
- Mechanical multi-file rewrite: execute_code script — paren-balance to capture
  full call text, targeted `re.subn` on first kwarg, splice by edit ranges;
  second pass inserts imports with paren-depth-aware scan; `python3 -m py_compile`
  every touched file immediately.
