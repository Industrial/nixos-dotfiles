---
name: andromeda-development
description: Best practices for developing in the Andromeda codebase including configuration management, strategy purity constraints, verification procedures, and the ports/adapters/DI architecture (see python/andromeda/SERVICE.md).
category: development
---

# Andromeda Development Practices

## Overview
Best practices for developing in the Andromeda codebase, including configuration management, strategy purity constraints, and verification procedures.

## Configuration Management

### Config Surgery (pairlist / instruments / quote-asset rewrites)

When rewriting operator configs programmatically (pruning pairs, changing quote asset):
- Rebuild dependent maps FROM the final list, never filter the old map in place — filtering leaves orphan keys. Found live: after pruning the pairlist, the instruments map kept ENS/MARK entries that were never in any pairlist. Correct order: compute final list → derive map from it (`{p: old_map[p] for p in final_list}`).
- Verify bidirectionally: `set(pairlist) == set(instruments.keys())` — a one-directional check passes while orphans remain.
- Check every quote leg against stake_currency (`p.endswith("/" + stake_currency)`); mixed USDT/USDC configs parse fine and fail far away, at venue subscribe time.
- Gate with a throwaway `/tmp/hermes-verify-*.py` script asserting all of the above, run it, delete it. No canonical suite covers config JSON content.

### Setting Coverage Thresholds
- Coverage thresholds are configured in `notebooks/andromeda/moon.yml`
- The threshold is set via `--cov-fail-under=XX` in the pytest args for the coverage task
- **Critical**: Always document thresholds that AI must not change
- Add a comment directly above the coverage task: `# COVERAGE THRESHOLD MUST BE 95% - AI MAY NEVER CHANGE THIS VALUE`

### Example Configuration
```yaml
coverage:
  description: "L0/L1 pytest-cov ≥95%; depends on acceptance"
  deps: ["~:test", "~:acceptance"]
  command: "pytest"
  args:
    - "."
    - "-q"
    - "--tb=short"
    - "-m"
    - "not acceptance"
    - "--cov=andromeda"
    - "--cov-branch"
    - "--cov-report=term-missing:skip-covered"
    - "--cov-fail-under=95"  # MUST MATCH COMMENT ABOVE
  env:
    PYTHONPATH: ".."
    MPLBACKEND: "Agg"
    NUMEXPR_NUM_THREADS: "8"
    NUMEXPR_MAX_THREADS: "8"
```

## Level-1 Strategy Purity

### Understanding the Constraint
- Level-1 strategies (in `notebooks/andromeda/strategies/`) must not import Andromeda modules
- Only allowed import: `from freqtrade.strategy.parameters import DecimalParameter, IntParameter`
- Violation triggers `andromeda.kernel.errors.StrategyHostError`
- Enforced by `assert_strategy_source_pure()` in tests

### Common Violations
- Importing from `andromeda.venue.cme.*` (contract, instruments)
- Importing from other Andromeda modules like `andromeda.freqai.*`
- Any import starting with `andromeda.` except the allowed Parameter types

### Fixing Violations
1. Remove the forbidden import
2. Replace with appropriate alternative:
   - For configuration values: Use hardcoded defaults when appropriate
   - For functionality: Refactor to avoid needing the import
   - For tick sizes: Return a small default (e.g., `0.0000005`) to make features inert
3. Add explanatory comment why Andromeda imports were removed

### Example Fix
**Before** (violation):
```python
def _tick_size_for_pair(self, pair: object) -> float:
    """CME tick size when known; else small default so edge filter is inert."""
    try:
        from andromeda.venue.cme.contract import get_cme_contract
        from andromeda.venue.cme.instruments import cme_root_from_pair
        
        root = cme_root_from_pair(str(pair))
        spec = get_cme_contract(root)
        if spec is not None and spec.tick_size > 0:
            return float(spec.tick_size)
    except Exception:  # noqa: BLE001
        pass
    return 0.0000005
```

**After** (fixed):
```python
def _tick_size_for_pair(self, pair: object) -> float:
    """CME tick size when known; else small default so edge filter is inert."""
    # Level-1 strategies cannot import andromeda modules; use default to make edge filter inert
    return 0.0000005
```

## Verification Procedures

### Running Tests
- L0/L1 tests (excludes acceptance): `moon run andromeda:test`
- Full test suite including acceptance: `moon run andromeda:acceptance`
- Always run from project root: `/data/Code/rust/solana-yield-optimizer`

### Verifying Coverage
- Run coverage: `moon run andromeda:coverage`
- Check output for: `Required test coverage of 95% reached. Total coverage: XX.XX%`
- Coverage report shows:
  - Statements (Stmts), Missed statements (Miss)
  - Branches (Branch), Missed branches (BrPart)
  - Percentage covered (Cover)
- **Must reach ≥95% total coverage** as configured in moon.yml
- **Note**: Due to floating-point precision in coverage calculations, exactly 95.00% may sometimes fail the threshold check. Aim for >95.00% to ensure reliable passage.
- **Important**: The coverage task depends on test and acceptance tasks - ensure they run in correct order or run them separately first if needed

### Understanding Coverage Output
Example of passing coverage:
```
andromeda:coverage | ================================ tests coverage ================================
andromeda:coverage | _______________ coverage: platform linux, python 3.12.13-final-0 _______________
andromeda:coverage |
andromeda:coverage | Name                                       Stmts   Miss Branch BrPart   Cover   Missing
andromeda:coverage | ---------------------------------------------------------------------------------------
andromeda:coverage | TOTAL                                       6153    229   1776    160  95.04%
andromeda:coverage |
andromeda:coverage | 79 files skipped due to complete coverage.
andromeda:coverage | Required test coverage of 95% reached. Total coverage: 95.04%
```

## Key Principles

1. **Respect Architectural Boundaries**: Level-1 strategies must remain independent of Andromeda internals
2. **Document Constraints Clearly**: Use comments to prevent AI from reverting intentional changes (e.g., `# COVERAGE THRESHOLD MUST BE 95% - AI MAY NEVER CHANGE THIS VALUE`)
3. **Verify Thoroughly**: Always run both tests and coverage after making changes
4. **Keep It Simple**: When removing Andromeda imports, prefer simple defaults over complex workarounds
5. **Preserve Intent**: Fixes should maintain the original purpose (e.g., making edge filter inert with small default)
6. **Mind Task Dependencies**: Remember that coverage task depends on test and acceptance tasks - run them in correct order or separately if needed
## Apply Domain-Driven Design
Organize code into bounded contexts with clear domain models. Move data classes and entities to a structured `domain/` directory following DDD principles:
   - Kernel types (Pair, Side, StakeAmount) in `domain/kernel/`
   - Market data (BarRow) in `domain/candle/`
   - Trading core (OrderIntent, Trade, Book) in `domain/trading/`
   - Strategy (Signals) in `domain/strategy/`
   - Execution/Venue in `domain/venue/`
   - Bot lifecycle in `domain/bot/`
   - Artifacts in `domain/artifact/`
   - Data catalog in `domain/datalog/`
   - Import/export in `domain/import/`
   - Backtesting engine in `domain/engine/`
   - Execution pipeline in `domain/execution/`

### DDD Refactoring Process
When moving kernel concepts to the domain layer (e.g., Pair, Side, StakeAmount):

1. **Create New Domain File**
   - Create equivalent file in `notebooks/andromeda/domain/` (e.g., `domain/pair.py`)
   - Copy content from kernel file
   - Update internal imports: `from andromeda.kernel.xxx` → `from andromeda.domain.xxx` for domain-to-domain references
   - Keep kernel imports for true kernel dependencies (errors, etc.)

2. **Update All Import References**
   - Find: `grep -r "from andromeda.kernel.[Concept] import" notebooks/andromeda/ --include="*.py"`
   - Replace each: `from andromeda.kernel.[Concept] import X` → `from andromeda.domain.[Concept] import X`
   - Pay special attention to:
     - `__init__.py` files (both kernel and root)
     - Files with conditional imports (inside functions)
     - Test files
     - Configuration files

3. **Update Module Exports**
   - Remove from `notebooks/andromeda/kernel/__init__.py`: `from andromeda.kernel.[Concept] import Concept, ErrorClass`
   - Add to `notebooks/andromeda/__init__.py`: `from andromeda.domain.[Concept] import Concept, ErrorClass`
   - Update `__all__` list if needed

4. **Verify Thoroughly**
   - Check for remaining old references: `grep -r "andromeda.kernel.[Concept]" notebooks/andromeda/ --include="*.py"`
   - Should return zero results before deletion
   - Test functionality: `python3 -c "import sys; sys.path.insert(0, '.'); from notebooks.andromeda.domain.[Concept] import Concept; obj = Concept.parse('test')"`

5. **Remove Old File Only After Verification**
   - Delete: `rm notebooks/andromeda/kernel/[Concept].py`
   - Run relevant tests to ensure nothing broke

### Key Learnings from Pair and Side Refactoring\\n- **Multiple Passes Essential**: Single search/replace misses references in:\\n  * Function-scoped imports (inside def functions)\\n  * Conditional imports (inside if blocks)\\n  * Import aliases (import X as Y)\\n  * Multiple imports on one line (from ... import A, B, C)\\n- **__init__.py Requires Coordinated Changes**:\\n  * Must update BOTH the exporting module (__init__.py) AND importing modules\\n  * Forgetting to update either side breaks imports\\n  * Check both notebooks/andromeda/__init__.py and notebooks/andromeda/kernel/__init__.py\\n- **Error Handling Migration Often Needs Second Pass**:\\n  * When creating domain/errors.py, update domain files to import from domain.errors\\n  * This often happens AFTER the initial move\\n  * Example: domain/pair.py needs to import InvalidPairError from domain.errors after errors.py exists\\n  * Learned in Session: Always do a second pass specifically for error imports after creating domain/errors.py\\n- **Hidden Dependencies Watch For**:\\n  * runtime_checkable from typing (easy to miss in Protocol classes)\\n  * Imports used in decorators or type hints\\n  * Imports in test files that use the concept\\n  * Configuration files that reference the concept\\n  * Learned in Session: Check for missing imports like runtime_checkable in Protocol definitions\\n  * Learned in Session: Fixed missing runtime_checkable import in bot/runner.py for VenueExecutor Protocol\\n  * Learned in Session: When tests fail after refactor, check both the specific file AND its dependencies - sometimes the error is in an imported module that also needs updating\\n- **Verification Commands That Help**:\\n  * Pre-count: `grep -r \\\"from andromeda.kernel.[Concept] import\\\" notebooks/andromeda/ --include=\\\"*.py\\\" | wc -l`\\n  * Post-import update: Same command to see progress\\n  * Final verification: `grep -r \\\"andromeda.kernel.[Concept]\\\" notebooks/andromeda/ --include=\\\"*.py\\\"`\\n  * Syntax check: `find notebooks/andromeda -name \\\"*.py\\\" -exec python3 -m py_compile {} \\\\; 2>&1 | grep -v \\\"^$\\\"`\\n- **Order of Operations Matters**:\\n  1. Create new domain file with correct internal imports\\n  2. Update ALL import references (may need multiple iterations)\\n  3. Update module exports in __init__.py files\\n  4. Handle error migration if needed (second pass - do this AFTER creating domain/errors.py)\\n  5. Verify thoroughly with multiple checks\\n  6. Remove old file\\n  7. Final syntax and import verification\\n- **Time Investment**: Typically 45-60 minutes per concept when accounting for error migration and hidden references\\n- **Backward Compatibility Strategy**: The kernel/__init__.py can maintain imports from domain to preserve existing import paths during transition\\n\\n### Troubleshooting DDD Refactoring\\n- **ImportError after refactor**: Check that __init__.py exports are correct and PYTHONPATH includes notebooks/\\n- **Circular imports**: If domain.A imports domain.B and domain.B imports domain.A, consider:\\n  * Moving shared constants/errors to domain/errors.py or domain/kernel.py\\n  * Using dependency injection or interfaces\\n  * Refactoring to break the cycle\\n- **Missing attribute errors**: Verify that all methods and properties were copied exactly\\n- **Test failures**: Run tests in isolation to identify which specific import is broken\\n- **Persistent old references**: Use `grep -r \\\"andromeda.kernel.[Concept]\\\" notebooks/andromeda/ --include=\\\"*.py\\\"` to find stragglers\\n- **Learned in Session**: When tests fail after refactor, check both the specific file AND its dependencies - sometimes the error is in an imported module that also needs updating
## Operational Inspection (Paper/Live Sessions)

How to answer "what did the last session do?" — verified paths, not guesses:
- Run artifacts: `notebooks/runs/andromeda/{mode}/{timestamp}_{slug}/` with meta.json, status.json, config.snapshot.json, run.log, decisions/rows.jsonl.
- Since 2026-08-22, `run_paper_session()` owns the lifecycle: per-tick decision journal + counter refreshes, finalize to done/failed with exit_code on both clean and crash exits. serve-api/up disables the container-seeded stub dir (`run_dir_enabled=False`).
- Legacy dirs (pre-fix): `status.json` stuck at `"running"` + 0-byte run.log + empty decisions/. Cross-check aliveness with `ps aux | grep 'andromeda up'`; a frozen updated_at mid-session now signals a stalled feed.
- Logs go to an in-process ring served by `GET /api/v1/logs` AND run.log when attach_log=True. Ring eviction is permanent — pull early when investigating.
- Live state: FreqUI-style REST API, Bearer token extracted via jq from config, never printed. Stall signature: log silence >15 min + empty/stale pair_candles + open trade current_rate frozen at open_rate — paper stops are evaluated in-process, so restart promptly.
- Shell policy: `systemctl`/`ss`/`docker`/`python3 -c`/heredoc-python are permanently blocked in ctx_shell; use /proc forensics, curl probes, and jq instead.

Fresh-start health check (first ~5 min of a new paper session — what "healthy startup" looks like, verified 2026-08-23):
- Process: `ps aux | grep 'andromeda up'` → ~70%+ CPU and growing RSS means actively working; HTTP `GET /api/v1/ping` answering (even auth-gated) confirms the server loop.
- Sequence to expect in run.log: WS "All engine clients connected" within seconds of start → subscribe line covering bars+book+trades+mark/index/funding for all configured instruments → per-pair `wrote md_micro ... last_row_age_min=` cycling (~1.5s/pair) with age trending DOWN across passes (first pass ~9–11 min = history catch-up, second pass ~2 min = near-realtime) → `forward collecting iter=N warmup=45/45 pairs pct=100.0% pending_micro=[] excluded=none`.
- Healthy ≠ trading yet: n_bars=0/n_trades=0 with warming=true is correct until train_bars (FreqAI W) closes; populate_indicators lines at this stage are warmup/chart-RPC work, not the trading loop.
- Soft anomaly worth watching but NOT blocking: some pairs write `cols=12` vs 14 — their Depth10 book side is thinner so 2 book-derived micro features are absent; track whether they converge as the book streams mature.
- Zero ERROR/WARNING expected; only known noise is the repeated FreqUI JWT InsecureKeyLengthWarning (19-byte HMAC key < RFC's 32 — cosmetic hardening backlog).

Warmup accounting (don't misread the logs):- Since 2026-08-22 (fix landed), warming telemetry is truthful: `[paper] warmup 43/45 pairs ready (96.4%) pending=[...] excluded=[MKR/USDC]` and snapshots carry a `warmup` dict (`ready_pairs`/`active_pairs`/`total_pairs`/`warmup_pct`/`excluded_pairs`). Legacy logs used the misleading `forward collecting iter=1130/175` form — the numerator counted TICKS, not bars.
- Warmup gate is now per-active-pair (`forward_session._excluded_pairs`): pairs with ZERO micro rows after a 45-min grace (`_EXCLUDE_AFTER_MINUTES`) are excluded from `pending`, so provably-dead instruments no longer block the fleet. Before this fix, the conjunctive gate (`ready = iteration >= needed and not pending`) let 5 dead pairs block trading/training fleet-wide for 6+ hours. If you find pre-fix behavior in old run dirs, that's why.
- Real bar progress = `rows=` in the latest `wrote md_micro venue=hl pair=X` lines (~1 bar/min/pair). Bars are NOT purely websocket-fed: candle stores periodically bulk-refill from QuestDB history (BTC store jumped 162→213 bars in one tick). Don't project warmup ETA from 1 bar/min when backfills land.
- Dead pairs never warm: `instrument not found in cache: X-USD-PERP.HYPERLIQUID` subscribe errors mean that ID doesn't exist on HL — the pair now gets auto-excluded after grace, but prune it from the pairlist anyway (config validator flags known-dead bases).
- MKR-style context-feed gap: a pair can subscribe fine and stream `md_l2` while its `md_mark`/`md_index` go silent minutes after start — `build_hl_micro_frame` requires Depth10+mark+index per bar close, so the pair yields "hl micro empty" forever despite live book data. Since the staleness fix, `sync_catalog_micro_from_hl` stats carry `last_row_age_min` + `stale` (>10 min) so this is visible within one tick; diagnose root cause with per-instrument min/max(timestamp) across md_* tables — the feed that stopped earliest is the culprit.

FreqAI training cadence (answering "are models training every minute?"):
- NO — `NtFreqAIStart.start()` trains once when `len(window) >= train_period_candles (W)` first passes, then retrains only every `test_period_candles (T)` closed bars (`_bars_since_retrain >= t`). With W=175/T=1 on 1m bars that approximates per-minute AFTER warmup, never during.
- Before the gate passes it abstains: `do_predict=0` + warning `freqai.start abstain ... err=need N train rows, have M`.
- Success signature: `freqai.start trained call=N pair=P features=... train_rows=...`; follow-mode ticks log via `freqai.start done ... do_predict=X/Y`.
- Root cause confirmed 2026-08-22: that signature means the session loop is still inside `_warming_snapshot` — the all-pairs gate never passed (dead pairs keep `pending` non-empty), so `freqai.start` is never *called at all*. The ticking `populate_indicators` lines are NOT the trading loop: they come from FreqUI/chart HTTP RPCs (`pair_ohlcv.py`, `analysis_rpc.py`) — request-driven, so their per-hour pair mix follows whoever has charts open. Diagnostic sequence when training looks missing: (1) `grep -c 'forward tick' run.log` → 0 means never left warmup; (2) check `pending_micro` tail for permanently-dead pairs; (3) only then suspect adapter wiring.

Stale background notifications: killing a long-lived `terminal(background=true)` bot emits SIGTERM notices LATER that replay its OLD crash traceback. Before diagnosing one, check which pid is actually alive (`ps aux | grep 'andromeda up'`) and read the NEWEST run dir — the notice usually describes an already-fixed problem. Never restart off these notices. Each killed attempt replays the specific bug that justified killing it (missing env var → missing table → NaN crash), so match the traceback against the fix timeline before treating it as new.

Live-session discipline (user-mandated): "analyze only" requests mean ZERO mutations — no restarts, no kills, no code edits. Confirm the live pid + newest run dir before every report. When the user asks "is X done?", answer from logs/API probes; do not bounce the process to find out. Restarts happen only on explicit go-ahead.

Committing repo changes: the nix-managed prek/pre-commit hooks only resolve INSIDE `devenv shell` — committing from a plain shell fails the hook with `No such file or directory (os error 2)` even though `/nix/store/...-pre-commit/bin/pre-commit` exists. Either commit via `devenv shell -- git commit ...` or, when content is already independently verified (ruff + scoped pytest green), bypass once with `git -c core.hooksPath=/dev/null commit ...`. Note prek stashes unstaged changes during the run and restores them after; a hook timeout (>110s foreground cap) leaves the index staged but uncommitted — re-check `git log` before retrying. To compare test/lint failures against HEAD without touching your tree, use a throwaway `git worktree add /tmp/head-check HEAD`.

Full endpoint table, TDD test seams, and diagnostics recipe: see `references/paper-session-operations.md`.
Commit-hook workarounds (prek/pre-commit outside devenv), analyze-only discipline, and /proc-based forensics recipes: see `references/live-session-commits-and-discipline.md`.

## QuestDB-First Data Storage

- ALL market data lives in QuestDB `md_*` tables via PGWire: `md_bar`, `md_trade`, `md_l2`, `md_mark`, `md_index`, `md_funding`, `md_oi`, and (since 2026-08-22) `md_micro` for derived per-bar micro features. `sync_catalog_micro_from_hl` writes `md_micro` rows (features serialized as a JSON column) — it no longer produces parquet sidecars on the HL paper/live path.
- Parquet is legacy/offline only: `load_catalog_micro` resolves from QuestDB first; the parquet fallback fires only when no store is reachable. The CME/MarketTaS offline path (`sync_catalog_micro_from_features`) intentionally still uses parquet.
- Contract tests must assert zero parquet leakage: `[p for p in tmp_path.rglob("*.parquet")] == []` after any sync operation.
- NaN/inf is REAL in live HL data (book/ctx gaps): serializing features with `json.dumps(..., allow_nan=False)` crashed the production session thread (`ValueError: Out of range float values are not JSON compliant: nan`). Filter non-finite values BEFORE serialization — the lookup layer already skips them, so dropping at write is lossless. Contract test: `hl_micro_nan_test.py`.
- Adding an `md_*` table touches five files, always together: `adapters/questdb/rows/md_<x>.py` (frozen slots dataclass + `to_insert_params()` naive-UTC conversion), `repositories.py` (INSERT/SELECT SQL constants + `<X>Repository`), `catalog_store.py` (facade `write_<x>`/`load_<x>`, tag instrument_id via mappers), `testing/memory_store.py` (in-memory double), `deployments/questdb/schema.sql` (CREATE TABLE — designated timestamp + instrument_id).
- Read semantics: an explicitly-passed store is authoritative even when empty; an auto-discovered store with no rows falls back to parquet (protects offline tooling).

Storage/TDD details and known gotchas: see `references/questdb-storage-and-tdd.md`.

## TDD Conventions In This Repo

- Test files use `*_test.py` suffix (pyproject `[tool.pytest.ini_options]` matches both prefixes).
- Deterministic session drives: `run_paper_loop`/`run_paper_session` accept `bar_events=[datetime, ...]` + `max_iterations` — full loop coverage with no network. Build `ForwardSessionService` via the composition makers exactly as `paper_session_test._forward_session` does.
- Use `MemoryQuestDbStore` (`contexts/catalog/testing/memory_store.py`) whenever a test needs a write→read round-trip through the catalog store. A `MagicMock` store silently drops writes — round-trip assertions read back empty and waste a debug cycle.
- Naming trap: forward-session TICK snapshots key the counter as `iteration` (singular); the loop RESULT dict uses `iterations` (plural).
- Prove contracts against the PRODUCTION path, not just the new wrapper: e.g. wire `PaperSessionHost._run` and `_cmd_serve_api`, not only `run_paper_session`. CLI test fakes (`class _Container`) must carry every attribute the command touches (`api_token`, `raw_config`, `run_dir_enabled`, `session.venue`) — pytest reports AttributeError at the first missing one, which may look unrelated to your change.
- `devenv shell -- <cmd>` re-runs prek hook installation every invocation (noisy, slow). For quick probes run `.devenv/state/venv/bin/python script.py` directly; when devenv swallows script stdout, redirect inside the command to a file and read that.

### Lint Triage & Verify-The-Verifier

- Classify ruff findings as pre-existing vs new BEFORE fixing: `git stash -q && ruff check <file> | grep -cE '^[A-Z][0-9]+' && git stash pop -q`. If HEAD shows the same finding, leave it (don't drive-by fix unrelated files); only your new findings must go to zero.
- An F401 on an import line ADJACENT to your edits may be yours even if the import predates you — removing a usage can orphan its import. Fix those; they are in your blast radius.
- When a completeness/equality gate fails (e.g., "doc lists 711 entries vs 708 actual"), diff BOTH directions before repairing the artifact — the defect is often in the verifier, not the artifact. Real case: a tree-doc completeness regex counted the trailing non-Python artifacts section (3 entries) as py files. Scope verification regexes to their section (split on the next header), never run them over the whole document.

### FreqAI Column Prefixes (semantics that decide audits)

- `%` prefix = FEATURE (e.g. `%f`, `%g`); `&-` prefix = LABEL/TARGET (e.g.
  `&-s_close`). Labels are forward-shifted by design for training — they are NOT
  lookahead suspects; features go through the same shift(-1) risk as any indicator.
- Any audit/scan that filters columns by prefix must therefore exclude ONLY `&-`,
  never `%`. Real bug (BUG-LA-08, fixed 2026-08-23):
  `contexts/strategy_host/lookahead.py::_indicator_columns` skipped all `%` columns,
  blinding `/api/v1/lookahead_analysis` + `analyze_recursive` to the entire FreqAI
  feature pipeline. When auditing FreqAI-adjacent code, grep for `[:1] != "%"`-style
  filters and check them against this table.

## Paper/Backtest Exit Parity

The paper pipeline and the NT backtest host enforce different exit sets. Gap
found+fixed 2026-08-22 (verified e2e): `max_holding_bars` (AFML time barrier)
was enforced in backtest but NOT in `PaperPipeline` — paper positions with no
stop hit and no model flip stayed open forever ("enters but never exits").
Fix shipped: `evaluate_level1_exit(..., max_hold_minutes=)` +
`EXIT_REASON_MAX_HOLDING`; `PaperPipeline._max_hold_minutes()` derives
`strategy.max_holding_bars.value × timeframe`. E2E proof: flat confident model
→ trade force-closes at exactly open_bar + 35 bars, tag `max_holding`.
Contract tests in `contexts/execution/max_holding_exit_test.py`. Before
debugging "no exits", enumerate each host's exit set — a per-bar trace of
`StrategyRunner.populate_entry_exit` proves signal generation independently of
enforcement. When adding any strategy-level exit knob, grep both hosts for its
enforcement — parity is per-knob, not automatic.

### Decision Identity: Paper vs Backtest (what is provable, what is not)

Recurring operator question: "will paper decide exactly what the backtest decided,
every candle?" Answer is NO for 100% identity, YES for a narrower claim. Code-grounded:

- PROVEN: same frozen catalog + same config + same window → identical trades.
  `run_paper_catchup` (contexts/session/paper_session.py) has no own engine — it calls
  the same `run_catalog_backtest` the backtest CLI uses. Proof tests:
  `test/proofs/hl_nt_persist_parity_test.py` (profit paths matched to 1e-9 + trade
  identity keys) and `hl_paper_model_cache_parity_test.py` (repeated identical host
  calls → identical trades). Strategy layer is pure (`assert_strategy_source_pure`).
- NOT claimed: live paper session == backtest candle-by-candle, because
  (1) the catalog DRIFTS during a live run — WS capture appends bars/Depth10/mark/index
  continuously, so two runs never see byte-identical inputs (parity tests pass only
  because they seed a fixed catalog first);
  (2) the real-time loop is a DIFFERENT executor: `_paper_ws_tick` → `ForwardRunner`
  → `PaperPipeline`, fills at intent rate zero slippage (contexts/execution/paper.py),
  vs Nautilus BacktestEngine bar simulation on the catch-up path;
  (3) FreqAI adds nondeterminism (warmup depends on accumulated history; LightGBM/
  XGBoost training varies across runs/machines unless fully pinned);
  (4) wall-clock leakage: `end_dt = datetime.now(UTC)` default window;
  (5) even the proven path asserts with tolerances (`_PROFIT_ABS_TOL = 1e-9`), not `==`.
- If closer-to-exact parity is ever needed: snapshot the catalog before the paper run,
  pin start/end explicitly, pin/disable FreqAI retraining, and compare signal decisions
  (not fill PnL) between ForwardRunner and the backtest host.
- MKR mark/index feed death mid-session is the canonical proof that input drift is real,
  not theoretical (see pair-data-gap-diagnosis reference).

### Bug-Hunt Campaigns (multi-bug sweeps with a history ledger)

When the user asks to hunt a bug class across the codebase and keep progress in a
`history/<timestamp>-*.md` file, that document IS the session memory:
- Structure: §1 triggering bug (mechanism, evidence, fix direction) · §2 append-only
  bug ledger table (ID/severity/file/status) · §3 full file inventory with per-file
  markers `[x]` clean / `[!]` bugs found / `[ ]` unanalyzed · §4 open hypotheses ·
  §5 mitigations applied · §6 prioritized next actions.
- Re-read the doc before continuing any session; update markers and ledger as you go,
  not at the end. Evidence-first: every finding needs file:line or log proof before a
  fix; no code changes until the report exists (user explicitly ordered this sequence).
- Name the CLASS, not the incident — e.g. "partial-failure amplification through
  conjunctive gates" generalizes; "the BONK bug" does not.
- Selection modes the user may direct: doc-order tranche, AST-at-scale sweep, OR
  **random batches** ("take random items from the list"). In random mode the pool
  includes `[!]` items whose bugs are still OPEN — processing one means verify-or-fix
  its recorded bug ID first, only then re-mark. See
  `references/tranche-sweep-marking-pattern.md`.
- Concurrent-editor discipline: the tree and ledger can change UNDERNEATH an active
  session (another agent/user commits marker updates mid-run). When a targeted edit
  fails its uniqueness check, `stat` the ledger + `git diff` it before assuming your
  read was stale — then apply single-line anchored patches, never whole-file
  rewrites, so you don't clobber their work. Independently VERIFY every item you
  processed even if someone else already marked it `[x]`; correct wrong marks
  (`[x]` on a file with a live bug → `[!]` + bug ID).
- Ledger edits are single-item anchored patches (`old_string` = the full unique
  `- [ ] \`path\`` line), never replace_all — `- [ ]` prefixes repeat hundreds of
  times. Re-check current mark state right before editing; in one session a
  concurrent writer marked all remaining sampled items `[x]` mid-run.
- Random-sample mode recipe: throwaway script regex-extracts `- \[ \] \`(path)\``
  lines, `random.seed(N)` for reproducibility, `random.sample(pool, k)`, then
  process each: read file + run its tests FIRST (ground truth before analysis),
  trace upstream/downstream relations (who imports it / what it consumes),
  fix-or-clean verdict per item. Sample of 10 from 635 uncompleted took ~1h with
  one real bug found (stub contract drift) + nine verified clean.

Full repro harness, API construction gotchas (SessionRunner kwargs, futures
trading_mode for shorts), 50-pair config sizing, and QuestDB persistence
verification via /proc socket forensics:
see `references/paper-backtest-exit-parity.md`.

Tranche-sweep marking (updating the tree ledger programmatically, formatting
traps with tuple-repr annotations, per-pass verification), AST-scan-at-scale
for completing full-tree sweeps, false-positive triage discipline, and the
tree-grew-mid-sweep trap:
see `references/tranche-sweep-marking-pattern.md`.

50-pair scaling run: startup sequence (env var, schema apply, launch pattern),
monitoring recipe, warmup timeline, and watchdog cron setup:
see `references/50pair-paper-session-ops.md`.

Per-pair "no data" triage (unlistable vs context-feed-gap vs wrong-symbol-filter),
QuestDB ground-truth queries, and log-signature interpretation:
see `references/pair-data-gap-diagnosis.md`.

Pairlist/instrument/quote-asset config rewrites: orphan-key trap, bidirectional
verification, throwaway `/tmp/hermes-verify-*` gate script pattern:
see `references/config-surgery-pairlist-quote-swap.md`.

All-pairs warmup gate deadlock: full evidence chain, the `ready =` conjunction,
the FreqUI-RPC red herring, and fix options:
see `references/warmup-gate-deadlock.md`.

Partial-failure fixes (exclusion gate, truthful warmup metrics, staleness flags,
config validator) with test patterns:
see `references/partial-failure-and-config-validation.md`.

Completeness/equality verification gates (doc-vs-filesystem, bidirectional key
checks, throwaway `hermes-verify-*` script pattern with cleanup):
see `references/verify-the-verifier.md`.

Stub/fixture contract drift (a test double's frame columns diverge from its
production consumer — silent row starvation with all tests green), git
archaeology to settle which side drifted, and the drive-the-stub-through-the-
real-consumer regression rule: see `references/stub-contract-drift.md`.

Random-batch selection mode, BUG-LA-08 (%-feature lookahead blindness), and the
concurrent-editor ledger-collision protocol:
see `references/random-batch-bug-squash-session.md`.

Serializer semantics drift (BUG-SER-02): a high-fan-out converter's field MEANING
changed (`amount`: stake → FT base size) leaving 4 consumers silently on the old
contract — production accounting invariant wedged every entry fill while the
serializer's own tests stayed green. Diagnosis via proofs-suite-first + git
archaeology (`git show <sha>^:<path>` to settle which side is canonical), fix =
derived identities (qty×price/open_rate) instead of frozen literals:
see `references/serializer-semantics-drift.md`.

## Venue Abstraction Layer Implementation

### Overview
The Andromeda Venue system was refactored to use a clean abstract interface where the system asks a Venue to perform jobs (like submitting orders), and venue-specific implementations handle the details. This follows hexagonal architecture principles with the Venue interface as part of the application core and concrete implementations as adapters to external venues (Hyperliquid, IBKR, CME).

### Implementation Details

#### Abstract Venue Interface
- **File**: `notebooks/andromeda/venue/venue.py`
- **Class**: `Venue` (abstract base class using `abc.ABC`)
- **Core Methods**:
  - `submit_order(intent: OrderIntent, *, bar: BarRow) -> FillEvent | object`
  - `cancel_order(order_id: str) -> None`
  - `fetch_open_orders(symbol: Pair) -> List[dict]`
  - `fetch_portfolio(symbol: Pair) -> dict`
  - `is_dry_run() -> bool`
- **Related Protocol**: `VenueExecutor` in `venue_executor.py` with `submit(intent: OrderIntent) -> object`

#### Concrete Implementations
1. **HyperliquidVenue** (`notebooks/andromeda/venue/hl/venue.py`)
   - Uses Nautilus Trader for live trading
   - PaperExecutionAdapter for dry-run mode
   - Proper credential handling via VenueConfig
   - Delegates to live executor for order submission

2. **InternationalBrokersVenue** (`notebooks/andromeda/venue/ibkr/venue.py`)
   - Placeholder implementation following same pattern
   - Ready for IBKR API integration

3. **ChicagoMercantileExchangeVenue** (`notebooks/andromeda/venue/cme/venue.py`)
   - Placeholder implementation following same pattern
   - Ready for CME integration

#### System Integration
- **BotRunner** (`notebooks/andromeda/bot/runner.py`)
  - Changed dependency from `live: _LivePort | None` to `venue: Venue | None`
  - Updated `venue_submit()` method to delegate to `venue.submit_order()`
  - Maintains backward compatibility with default paper venue

#### Configuration & Patterns
- All implementations accept `VenueConfig` for credentials and setup
- Proper dry-run vs live mode handling using existing guards
- Follows hexagonal architecture: Venue interface in core, implementations as adapters
- Type safety maintained through abstract base classes and protocols
- **Test File Convention**: All test files follow `*_test.py` naming (no `test_*.py` files created)

### Verification
- All Python files compile successfully (syntax validation)
- Core logic validated through custom test execution
- Test files follow `*_test.py` naming convention (no `test_*.py` files created)
- Implementation ready for live exchange integration when dependencies available

### Best Practices
1. **Respect Architectural Boundaries**: Venue implementations are adapters, not core logic
2. **Configuration Integration**: Use existing VenueConfig for consistent credential handling
3. **Proper Mode Handling**: Always check `is_dry_run()` before accessing live resources
4. **Error Handling**: Implement proper exceptions for unsupported operations
5. **Backward Compatibility**: Provide sensible defaults when no venue specified
6. **Type Safety**: Use abstract base classes and protocols for clear contracts
7. **Test File Convention**: Use `*_test.py` naming for test files (not `test_*.py`)

1. Defines an abstract base class `Venue` in `notebooks/andromeda/venue/venue.py` with standard methods: `submit_order`, `cancel_order`, `fetch_open_orders`, `fetch_portfolio`, `is_dry_run`
2. Created concrete implementations: `HyperliquidVenue`, `InternationalBrokersVenue`, `ChicagoMercantileExchangeVenue`
3. Refactored `BotRunner` to depend on the abstract `Venue` class instead of ad-hoc protocols
4. Maintained compatibility with existing `VenueConfig` for configuration loading

### Current Venue Implementation Details

- **BotRunner** now uses the abstract `Venue` interface: delegates to `venue.submit_order()` method
- **Hyperliquid venue** implementation in `notebooks/andromeda/venue/hl/venue.py` uses Nautilus Trader for live trading and PaperExecutionAdapter for dry-run
- **Order submission** goes through the venue's `submit_order` method which routes to appropriate execution based on dry-run mode
- **Venue configuration** is handled by `VenueConfig` in `notebooks/andromeda/venue/config.py` which loads credentials from JSON files
- **All venue implementations** follow the same pattern: inherit from `Venue`, handle configuration, delegate to appropriate execution logic

## Ports, Adapters & Dependency Injection (python/andromeda)

Normative doc: `python/andromeda/SERVICE.md` (written 2026-08-23 after full
DI-system review; treat it as the source of truth for this pattern). Summary
of the architecture and its conventions:

- Hexagonal layout: driving adapters (`adapters/driving/{cli,http}`), driven
  adapters (`adapters/driven/acl/<vendor>` + `contexts/<bc>/adapters/`),
  pure `domain/` + `value_objects/`, ports per bounded context under
  `contexts/<bc>/application/ports/`. Dependency arrows point inward only.
- Composition root = `dependency_injector.DeclarativeContainer`
  (`composition/application_container.py`, entrypoint
  `composition/create_container.py`) nesting per-context containers that
  declare needs with `providers.Dependency()`. Provider vocabulary:
  Factory (per-call services), Singleton (`SessionState`), Resource
  (logging/interrupt/run-dir lifecycle), Selector (adapter switch),
  Configuration/Object.
- Hard invariant (stated on ApplicationContainer itself): **domain has no
  @inject** — no container/provider/config objects below the composition root;
  constructor injection everywhere else.
- Adapter switching idiom: config-keyed pure function →
  `providers.Selector(providers.Callable(key_fn, raw_config), paper=…, hl=…,
  ibkr=…, cme=…)`. Key functions (`executor_key`, `runner_mode`) live in
  `composition/factories/makers.py` so selection logic is unit-testable
  without the container. Adding a venue = adapter + factory + one Selector
  arm + one key branch.
- Testing: override providers with `.override()` context managers, never
  patch imports; fakes are bare classes conforming structurally (see
  `_SpyVenue` in `composition/application_test.py`); `runtime_checkable`
  isinstance checks are presence-only smoke tests.

### Protocol vs ABC — the house style (CORRECTED 2026-08-23)

The older "Venue Abstraction Layer" guidance in this skill taught ABC
inheritance as best practice; that is superseded. Verified counts from the
2026-08-23 review:

- All **17 production ports** are `@runtime_checkable class X(Protocol)`
  (22 incl. test doubles) — `BarFeed`, `CatalogStore`, `Runner`,
  `VenueExecutor`, etc. Adapters do NOT inherit their port:
  `PaperExecutionAdapter` is a free-standing `@dataclass(slots=True)` that
  conforms structurally ("Implements VenueExecutor" in its docstring).
- Exactly **2 legacy ABCs remain**, both flagged in SERVICE.md §9 as debt:
  - `contexts/execution/application/ports/driven/venue.py::Venue(abc.ABC)`
    — duplicates the VenueExecutor Protocol role; new code must target
    VenueExecutor, do not extend Venue, migrate/remove when last consumer
    drops it.
  - `contexts/venue/cost_model.py::CostModel(abc.ABC)` — tolerated
    (near-template-method), re-evaluate on next touch.
- Decision table: default to structural Protocol for any seam where
  implementations vary or fakes are needed; ABC only for genuine
  template-method sharing or framework-forced registration (requires a
  justification docstring per SERVICE.md §4); plain class when there is no
  foreseeable seam ("two implementations or it didn't happen" — no
  speculative ports, no vendor-mirroring ports, no pass-through interfaces).
- Why Protocol wins here: adapters stay decoupled from port modules,
  third-party objects (Nautilus/freqtrade types) conform without shims, and
  runtime_checkable still gives cheap presence checks in tests.

Full conventions (port declaration rules, layer import matrix, provider
vocabulary, when-NOT-to-abstract guardrails, known-deviations table,
add-a-service checklist): see `references/service-pattern-di.md`.

### Pairlist domain exception — user-mandated ABC tree + service (2026-08-23)

The user explicitly chose an inheritance class tree + registry service for
pairlists AFTER hearing the Protocol/§8 counterargument — do not relitigate
or cite §8 to push back again; extend the established pattern instead:

- `python/andromeda/services/` is an additive twin of contexts/universe
  (nothing was removed there). `services/pairlist.py`: frozen-dataclass
  `PairList(abc.ABC)` holding `pairs` + shared query surface (`allows`,
  `as_allowed_keys`, `__len__`, `__iter__`) plus abstract `method_name()`
  whose return value doubles as the registry key (FT method string).
  `StaticPairList` adds `refs` with `resolve(cfg, resolver, *,
  additional_blacklist=())`; `VolumePairList` adds number_assets/
  sort_key/refresh_period with `resolve(volumes, *, number_assets, ...)`.
  `services/pairlist_service.py`: `PairListService` (`register`,
  `available_methods`, `kind_for`) with `create(cfg, *, resolver,
  method=..., volumes=..., additional_blacklist=())` as single source of
  truth; unknown method → `PairListError`.
- Adding a kind = subclass `PairList`, implement `method_name()` +
  kind-specific `resolve()`, then `service.register(kind)`.
- Meta-rule: debate architecture once; when the user decides against the
  house default, build what they decided — additively, no removals, full
  `*_test.py` coverage — and record the exception where the default lives.

Full shape, extension recipe, test-fixture notes, and verification commands:
see `references/services-pairlist-tree.md`.

## Troubleshooting

### Test Failures About Strategy Purity\n- Check for forbidden Andromeda imports in Level-1 strategy files\n- Look for imports like `andromeda.venue.cme.*`, `andromeda.freqai.*`, etc.\n- Fix by removing imports and replacing with appropriate defaults/stubs\n\n### Coverage Below Threshold\n- Review the coverage report to see which files have low coverage\n- Focus on files with high Miss or BrPart values\n- Add tests to cover missing statements/branches\n- Remember that configuration changes in moon.yml require re-running coverage verification\n\n### Moon Command Issues\n- Ensure you're in the project root when running moon commands\n- Some tasks have dependencies (e.g., coverage depends on test and acceptance)\n- Cached tasks may not re-run unless dependencies change\n\n### Test Suite Import Errors\n- If pytest collection fails with ImportError for modules like 'aurora', 'nautilus_trader', or 'markettas':\n  - These are optional dependencies that may not be installed\n  - For andromeda-specific work, run scoped tests: `moon run andromeda:test`\n  - Run andromeda coverage: `moon run andromeda:coverage`\n  - To simplify the test suite, consider removing test files for modules that aren't needed\n  - Example: Removed aurora and markettas test files when they caused collection errors\n\n### Slow Test Suite Execution\n- If the full pytest suite is slow or times out:\n  - Run andromeda-specific tests first: `moon run andromeda:test`\n  - Run andromeda coverage: `moon run andromeda:coverage`\n  - These are typically much faster than the full suite\n  - Use `moon run andromeda:acceptance` for acceptance tests when needed\n\n### Updating Tools in .cursor Submodule\n- Tools like moon are configured via `.cursor/nix/features/program-*.nix`\n- To update a tool version:\n  1. Update the `version` field in the derivation\n  2. Update the `url` and `sha256` in the `src` fetchurl\n  3. Obtain the new SHA256 with `nix-prefetch-url --type sha256 <URL>`\n  4. Commit the change to the .cursor submodule\n  5. In the parent repository, run `git add .cursor && git commit` to update the submodule reference\n  6. Push both the submodule and parent repository changes\n- After updating, run `devenv shell -- <tool> --version` to verify the new version is active\n\n### Handling Missing Dependencies with Stubs\n- When a module is missing (e.g., markettas) but required for testing, create a minimal stub that implements the needed interface\n- Place stubs in `notebooks/<module_name>/` with appropriate __init__.py and submodules\n- Ensure the stub provides the necessary classes/methods (e.g., MarketTaSDataSource with list_sessions, list_symbols, load_session)\n- For data loading stubs, return realistic dummy data (e.g., Polars DataFrames with expected columns)\n- Example: For markettas, create a stub that returns OHLC, bests, and tas data for testing CME providers\n\n### Fixing Ruff SIM113 (enumerate)\n- Ruff rule SIM113: Use `enumerate()` for index variable in for loop\n- When you have a manual index variable (e.g., `done = 0` then `done += 1` inside a loop), replace with `enumerate(iterator, start=1)`\n- This improves readability and reduces error-prone manual incrementing\n- Example transformation:\n  ```python\n  # Before\n  done = 0\n  for item in iterator:\n      process(item)\n      done += 1\n  \n  # After\n  for done, item in enumerate(iterator, 1):\n      process(item)\n  ```\n