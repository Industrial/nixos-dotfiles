# strategy_host dissolution — research + plan (2026-08-23, PLAN pending approval)

Target: `services/strategy_service.py`, ONE class `StrategyService`, flat
concrete (NO abc.ABC hierarchy — varying axis is WHICH strategy, and it enters
through injection, same reasoning as venue entering through injected executor).
User framing: "single central point of responsibility" for strategies.

## Placement map (verified against source)

`contexts/strategy_host/` = 19 files, ~2.0k LOC. Consumers verified via grep.

→ `domain/` (pure; no adapter imports):
- `informative.py` — merge_informative_pair + assert_informative_no_lookahead.
- `lookahead.py` — analyze_lookahead / analyze_recursive. Production consumer:
  adapters/driving/http/analysis_rpc.py.
- `purity.py` — AST guard "Level-1 strategies must not import andromeda".
  Its `_ALLOWED_MODULES` allowlist string MUST follow parameters.py to its new
  home or every fixture purity test breaks.

→ `adapters/driven/acl/freqtrade/` (vendor-coupled):
- `adapters/freqtrade/hooks.py` — all 14 FT callback verbs (custom_stoploss,
  custom_exit, custom_entry/exit_price, custom_stake_amount,
  confirm_trade_entry/exit, custom_roi, leverage, adjust_trade_position,
  adjust_entry_price, check_entry/exit_timeout, order_filled). Already imports
  TradeProxy + exit_reasons from acl/freqtrade. Production consumer:
  contexts/execution/pipeline.py imports ALL of them.
- `adapters/freqtrade/loader.py` — load_strategy, default_ft_strategy_config.
  Consumers: composition/factories/makers.py, cli/app.py, http app.py (NOTE:
  function-local import inside a try block at ~L170 — rename-sweep blind spot),
  http routes.py / pair_ohlcv.py / analysis_rpc.py, execution backtest +
  nt_backtest, freqai hyperopt engine.
- `adapters/freqtrade/proxies.py` — DataProviderProxy over CandleSource port.
  Tests-only consumers found; keep as adapter regardless (FT-shaped surface).
- `parameters.py` — Hyperopt Parameter re-exports (freqtrade.strategy.parameters)
  + discover/enumerate/sample/apply. Consumer: freqai_host/adapters/hyperopt/
  engine.py. NOTE: lives at context top level today but is FT-vendor-coupled →
  moves to acl/freqtrade/, not domain/.

→ absorbed into StrategyService (class dies per shell-death law):
- `runner.py` StrategyRunner — populate_indicators/populate_entry_exit over a
  warm CandleStore. Zero own state beyond `strategy`. Ad-hoc constructions to
  collapse onto one DI-resolved service: pipeline.py build default,
  http/pair_ohlcv.py:215, http/analysis_rpc.py:118+185, makers.make_strategy_runner.

## Out of scope (separate dissolutions)

freqai_host (ML host — import rewrites only), catalog, execution
(PaperPipeline stays and CONSUMES StrategyService), microstructure,
instrument_map, venue remnants.

## Waves

1. Domain extraction: git mv informative/lookahead/purity (+ colocated tests)
   → domain/, scripted import rewrite, extend dissolved-domain purity gate list,
   ruff F821 sweep (function-local import trap).
2. ACL relocation: git mv hooks/loader/proxies/parameters →
   adapters/driven/acl/freqtrade/, rewrite purity allowlist path + all imports.
3. Service: services/strategy_service.py + colocated strategy_service_test.py.
   StrategyService holds loaded strategy + cached StrategyMetadata, exposes
   populate_indicators/populate_entry_exit (absorbed runner body) and the
   callback verb facade (strategy arg vanishes — service owns it). Rewire
   makers, execution/pipeline.py, 4 HTTP sites, cli/app.py, nt_backtest;
   update ft_17_* proofs, test/fixtures/short_only_test.py, application_test
   identity assertions. DI constructs it — no selector/factory.
4. Tombstone test for contexts/strategy_host, ARCHITECTURE.md canonical table
   row, remove strategy_host from ddd_layout_import_rules_test name list,
   final leftover grep empty, scoped pytest/ruff green, coverage floor 95%.

## Rulings received (2026-08-23) — ALL as recommended

1. Absorb StrategyRunner. 2. Verb facade on the service. 3. Flat concrete class
(runtime-checkable `domain/strategy_host.py` Protocol beside domain/runner.py;
pipeline consumes the port). 4. freqai_host out of scope.

Mid-wave user correction (DI): inline `StrategyService(...)` construction in
route bodies / analysis hosts violates injection law. Resolution: container
`providers.Singleton(make_strategy_runner)` + `strategy_runner` alias;
ApiApp gains injected `strategy_service` field with a documented LAZY FALLBACK
`_host()` for webserver-only entrypoints (stoploss display, forceenter/exit);
force bodies take `strategy_service` as a parameter; endpoints that resolve
strategies BY REQUEST NAME (analysis/plot) construct their host at the edge —
that is composition-at-the-edge, not a DI violation.

## Executed record (waves, SHAs)

- W1 885a0946 — informative/lookahead/purity (+tests) → domain/; purity renamed
  strategy_purity.py; 11 consumers rewritten.
- W2 09419876 — hooks/loader/proxies/parameters (+tests) → acl/freqtrade/;
  allowlist followed automatically via string replace; 39 files.
- W3 09a5e5d1 — StrategyService (populate_* + metadata() + 14 verbs DELEGATING
  to acl hooks — do not duplicate vendor-calling bodies in the service);
  PaperPipeline collapses strategy+strategy_runner → one `strategy_service`
  field with a read-only `strategy` property shim; build_paper_pipeline KEPT
  its `strategy=` kwarg (wraps into service internally) so ~10 proof files
  needed zero churn; application identity test upgraded to §5.4 singleton.
- W4 f998ace1 — runner.py/runner_test.py deleted, package dir gone,
  test_strategy_host_context_dissolved tombstone, ARCHITECTURE.md table.

## Evidence-driven corrections

- Moving purity.py one level shallower broke its fixtures-root math
  (`parents[2]`→`parents[1]`) — surfaced only via ft_17_73's
  `len(checked) >= 5` assertion. Depth-derived paths need a test that asserts
  the resolved directory is non-empty.
- cli/app.py + execution/application/backtest.py needed ZERO wave-2 edits
  (load_strategy-only importers) — check what a dirty shared file actually
  imports before planning around it.
- A foreign COMMIT landed a stale buffer of makers.py reverting uncommitted
  wave-3 edits (see SKILL.md technique). Re-applied via scripted replaces with
  exact-count asserts against their HEAD, committed immediately.
- Whole-file rewrites of shared modules must be diffed against HEAD right
  after writing (dropped imports/PendingEntry defs caught that way).

Final intentional `strategy_host` mentions: error/strategy_host_error.py,
freqai legacy_pickle.py `_BC` pickle-path allowlist (historical compat),
tombstone docstring. Everything else greps empty.
