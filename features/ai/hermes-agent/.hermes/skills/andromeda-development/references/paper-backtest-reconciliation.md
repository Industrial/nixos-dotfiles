# Paper ↔ Backtest Reconciliation (HL freqai-afml, 2026-08-25)

Session record for the first real reconciliation pass: keep the paper session
running, replay the SAME window through the backtest host, diff, explain deltas.

## Setup under reconciliation

- Paper process: `python -m andromeda up --config andromeda/configs/andromeda.freqai-afml.hl.paper.json`, pid 2435212, started 11:20:10Z, run dir
  `notebooks/runs/andromeda/paper/2026-08-25_11-20-10_andromeda.strategies.freqai_afml_freqaiafmlstrategy/`.
- Pairlist: BTC/ETH/HYPE/SOL/BNB/XRP USDC, all shorts via `afml_short`, stake 1000 USDC.
- Replay window chosen: 11:20:00Z → 13:25:00Z (session start → capture frontier at launch).
- Discipline: zero mutations to the running session (analyze-only mandate held).

## Paper ground truth extraction (verified recipes)

- Auth: static bearer token WORKS — `api_server.api_token` from the config JSON as
  `Authorization: Bearer <token>` on every endpoint. Do NOT bother with JWT unless
  needed: login route is `/api/v1/token/login` (underscore form 404s silently as
  unknown-route JSON), basic-auth alone returns "missing api token".
- Endpoints used: `/api/v1/ping`, `/status` (open trades only), `/trades`
  (`{"trades":[...]}`, includes closed; `close_date!=null` ⇒ closed).
- Trade dict carries `enter_tag`, `exit_reason` (null for model-flip exits — only
  time-barrier exits carry `"max_holding"`), fee_open/close_cost = 0.0 (paper fills
  at intent rate, no taker fee model), `open_date` = signal-bar ts.
- Cross-check triad: status.json n_trades == /trades length == decisions/rows.jsonl
  n_trades tail. Journal rows: `{"iteration","n_bars","n_trades","warming","ts"}`.
- Log forensics: `grep -c 'freqai.start trained'` per pair gives per-pair training
  health; `warmup N/N pairs ready` marks gate-open; `bot_start ...` line prints
  EFFECTIVE knob values (see F1).

## QuestDB coverage audit

- Probe pattern: throwaway `/tmp/hermes-verify-recon-*.py`, psycopg2 to
  127.0.0.1:8812 qdb admin/quest (creds confirmed against a proven-working prior
  script, never printed), venv python `.devenv/state/venv/bin/python`.
- VENUE-TAG CASE TRAP (cost one false alarm): md_bar/md_l2/md_trade/md_mark/md_index
  store `venue='HYPERLIQUID' | 'CME'`; **md_micro stores `venue='hl' | 'cme'`**
  lowercase. A uniform-case filter returns clean-looking ZEROES. Always
  `SELECT venue, count(*) GROUP BY venue` unfiltered first.
- Day buckets: `timestamp_floor('1d', timestamp)` works through PGWire;
  `dateadd/datediff` forms error out; raw date-cast group-bys return silently-wrong
  counts (prior-session lesson, reconfirmed).
- HL data frontier (state at 2026-08-25): bars exist only 2026-08-20 (~250 bars) and
  06:18→13:20 today (~420/pair). There is NO external ingest for HL — history depth =
  whatever past paper sessions captured. HYPE starts 06:18 (joined then). All six
  pairs had l2/trade/mark/index/micro populated across the session window.
- md_micro columns: timestamp, instrument_id, source='hl_nt', venue='hl',
  features_json, ts_init_ns, ingest_run_id, schema_version. BTC/XRP payloads both
  14 keys, finite — persisted micro is NOT why XRP misbehaves (see open questions).

## Backtest launch mechanics

- Backtest host is SINGLE-PAIR per invocation (`pair = cfg.pairlist[0]`,
  historical_runner_service.py:96) — loop the CLI once per pair.
- Runner auto-backshifts catalog load start by `max(3×W, 600)` bars
  (domain/session_warmup.py) — with W=175 that is 600 bars, which reaches the
  morning session's bars (06:18+) so FE warmup is genuinely fed.
- Engine bars are then FILTERED to `--start` (`filter_bars_from_trade_start`,
  nt_compose.py:204); reported `n_bars` = post-filter count (126 for BTC's window).
- SILENT FAILURE MODE: a failing `andromeda backtest` exited rc=1 with EMPTY
  stdout+stderr (operator `_print_json_err` line swallowed by the run-dir log tee;
  run dir gets meta.json `error: "backtest failed"` + 0-byte run.log). Diagnosis:
  call `run_backtest()` directly in-process in a throwaway script to get the real
  traceback. Actual cause this session: shell lacked `QUESTDB_PG_URL`.
  Fix: `export QUESTDB_PG_URL=$(tr '\0' '\n' < /proc/<paper-pid>/environ |
  grep '^QUESTDB_PG_URL=' | cut -d= -f2-)` (never echo it).
- Successful-run results are best read from `<run_dir>/frequi_result.json`
  (`.strategy.FreqaiAfmlStrategy.total_trades/.trades/.trade_count_short` etc.);
  the CLI's operator JSON line did not surface in redirected stdout either.
- Walkforward caching: second identical run logs `PredictionStore hit key=… —
  skipping walk-forward train` (~instant). Knob changes still show up correctly in
  `bot_start`; treat cached prediction joins as potentially stale relative to any
  FE-affecting change.

## Findings

### F1 — Entry-gate divergence: config `afml` block never reaches paper (CONFIRMED)

Three-way evidence:

| knob | config json | paper effective (log) | backtest effective (log) |
|---|---|---|---|
| min_conf | 0.63 | 0.55 | 0.63 |
| min_edge_ticks | 4.8 | 4.0 | 4.8 |
| exit_conf_frac | 0.46 | 0.5 | 0.46 |

- Paper's `bot_start` line matches strategy CLASS DEFAULTS
  (_DEFAULT_MIN_CONF=0.55, _DEFAULT_MIN_EDGE=4.0, _DEFAULT_EXIT_FRAC=0.5 in
  strategies/freqai_afml.py) — paper has NO env overrides (checked /proc environ)
  and NO code path applying the config afml dict.
- Backtest applies it via `apply_afml_overrides(ft_strategy, raw_afml)`
  (nt_backtest.py:69). Only-host-applies = silent divergence.
- Consequence: paper entered MORE (looser conf/edge gates) than its own config
  intended; backtest-at-config-gates took 0 BTC trades vs paper's 3.

Env knobs that override BOTH paths (levers for parity experiments):
`ANDROMEDA_AFML_MIN_CONF`, `ANDROMEDA_AFML_MIN_EDGE_TICKS`, `ANDROMEDA_AFML_EXIT_FRAC`,
`ANDROMEDA_AFML_EXIT_CONF`, `ANDROMEDA_AFML_STARTUP`, `ANDROMEDA_AFML_MIN_HOLD`.

### F2 — Startup-gate pool asymmetry (CONFIRMED mechanism)

- NT adapter: `if len(self._rows) < max(startup_candle_count, 2): return`
  (strategy_adapter.py:169-171) — `_rows` accumulates ONLY engine bars, i.e. bars
  AFTER `filter_bars_from_trade_start`. startup_candle_count = 175 (class default),
  engine window = 126 bars ⇒ signal evaluation NEVER begins ⇒ 0 trades BY
  CONSTRUCTION regardless of model/gates. No warning is emitted.
- Paper forward gate: counts candle-store bars INCLUDING bulk refill from QuestDB
  history (~607 bars in store at decision time) ⇒ trading from the first ticks.
- So even identical inputs diverge structurally for any replay window shorter than
  startup_candle_count: paper decides, backtest cannot.

### Experiment matrix (BTC, 11:20→13:25Z)

| run | gates | startup | result |
|---|---|---|---|
| A (config as-is) | 0.63/4.8/0.46 | 175 | 126 bars, **0 trades** |
| B (paper-effective env) | 0.55/4.0/0.5 | 175 | 0 trades (gate-blocked) |
| C = DEBUG rerun (B + ANDROMEDA_AFML_STARTUP=10) | 0.55/4.0/0.5 | 10 | total_trades=0 BUT engine log shows an entry: BTC SELL filled 11:37:00Z @79,421 (0.0127 BTC, 0.4539 USDC taker commission) — **never exits** |

### RESOLVED: why Run C booked zero despite entering

`frequi_result.total_trades` counts CLOSED trades only. The DEBUG+TRACE rerun
(run dir 2026-08-25_13-46-25_*) proves the strategy DID trade once the startup
gate was unblocked:

- `populate_entry_trend` ran per bar over the full cached frame (234 calls);
  exactly ONE `Adding Market` order in the log (BTC short, filled as above).
- NO exit order ever followed: the NT adapter's exit path is signal-only
  (`strategy_adapter.py:215-266`, tags `exit_reason="exit_signal"`); there is
  NO max_holding/time-barrier force-close, so the short rode to window end
  and stayed open ⇒ never counted.
- Paper same window: 3 BTC closed trades incl. one forced `max_holding` at
  open+35 bars — paper enforces the time barrier (2026-08-22 parity fix),
  backtest does NOT. Parity is per-knob per-HOST: the fix landed on the
  paper pipeline side only.

HYPE replayed identically: 1 entry (@13:16), no exit. ETH/SOL/BNB: 0 entries
(prediction/gate differences — see F1/F3).

### F5 — Fee asymmetry

Backtest fills carry taker commission (0.4539 USDC ≈ 4.5bp on the BTC entry;
engine commission models attached at build_backtest_engine); paper fills are
free (fee_open/close_cost=0). Any matched-trade comparison must budget ~9bp RT
or PnL deltas are systematically overstated.

## Final reconciliation table (window 11:20→13:25Z)

| pair | BT entries | BT closed | PP trades | PP pnl (window) |
|---|---|---|---|---|
| BTC | 1 | 0 | 4 | −$6.14 |
| ETH | 0 | 0 | 5 | +$1.50 |
| HYPE | 1 | 0 | 3 | −$7.53 |
| SOL | 0 | 0 | 2 | −$3.14 |
| BNB | 0 | 0 | 5 | −$12.08 |
| XRP | excluded (user call) | — | 0 | — |
| TOTAL | 2 | 0 | 19 | −$27.38 |

Paper full-session context: 36 trades by 13:58Z, +$50.66 (early losers
recovered later — window slicing matters when reporting). Diff tool:
`/tmp/hermes-verify-reconcile-diff.py` (recount from raw API snapshot +
frequi_result cross-check); ad-hoc verifier pattern asserted 24–28 checks
incl. "entries observed in engine log" to separate never-entered from
entered-never-closed.

## Other observations (feeding later analysis)

- Paper exits were mostly model FLIPS (exit_reason=null), 2 of 12 max_holding;
  chained same-minute reopen patterns (BNB 12:48→12:49→12:51).
- Paper session healthy otherwise: 660 FreqAI trainings, warmup 6/6, zero ERRORs.
- XRP abstains EVERY call (`err=no rows available for training after dropna`,
  freqai_service.py:388) while its persisted micro features are clean/14-key. dropna covers feature_cols +
  label cols; suspect label-side NaNs in the IN-MEMORY frame (label derivation from
  triple-barrier on XRP's bar series) — NOT yet proven; XRP trained 146×0 in this
  session AND the morning one (grep morning run.log showed no abstain lines pre-fix
  era, so abstain began with this session's data shape).
- Morning sibling run (06-18-12, same config) closed 12 trades by 11:19 — the
  afternoon session's trades are NOT its continuation; sessions are independent
  FSMs sharing only the catalog.

## Reusable artifacts left behind

- `/tmp/recon_backtest.sh` — per-pair backtest loop (needs QUESTDB_PG_URL export).
- `/tmp/hermes-verify-recon-{coverage2,inventory,xrp-micro}.py` — QuestDB audits.
- `/tmp/recon_paper_by_pair.json` — paper trades grouped by pair (snapshot 13:14Z).
- `/tmp/hermes-verify-recon-bt-run{A,B}.py` — direct run_backtest probes with env knobs.
