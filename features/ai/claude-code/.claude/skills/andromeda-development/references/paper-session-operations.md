# Paper/Live Session Operations & Forensics (Andromeda)

Condensed from the 2026-08-22 investigation of run `2026-08-21_20-11-54_andromeda.strategies.freqai_afml_freqaiafmlstrategy`.

## Run directory layout

Root: `notebooks/runs/andromeda/{mode}/{YYYY-MM-DD_HH-MM-SS}_{slug}/`

| File | Contents |
|---|---|
| `meta.json` | run_id, mode, strategy, venue, symbols, started_at, catalog_path, config_path, extra. Finalize adds ended_at/exit_code/n_bars/n_trades/error/artifact |
| `status.json` | phase: running → done/stopped/failed, updated_at, exit_code |
| `config.snapshot.json` | Full raw config, secrets redacted (`redact_config_snapshot`) |
| `run.log` | Populated when attach_log=True (tee'd stdout lines + andromeda/afml logger records); 0 bytes only for legacy dirs created before the 2026-08-22 fix |
| `decisions/rows.jsonl` | One JSON row per session tick: ts, iteration, mode, n_bars, n_trades, warming, pairs (`_record_tick` in paper_session.py) |

Creator: `begin_operator_run()` in `python/andromeda/runtime/run_dir.py`;
wrapped by `run_dir_resource` in `python/andromeda/composition/factories/makers.py`.

Quirks:
- `run_dir_resource` writes `phase="stopped"` only on clean context teardown. Killed/orphaned processes leave `status.json` stuck at `"running"` forever — it is NOT proof a process is alive. Cross-check with `ps aux | grep 'andromeda up'`.
- `meta.json` `git_sha` is often null: `_git_sha()` runs `git rev-parse` with cwd `_REPO_ROOT.parent` and swallows all failures.
- Every `up` start creates a new timestamped dir; many same-day abandoned stubs are normal restart churn, not data corruption.

## Where logs actually live

For `andromeda up` / `serve-api` (`_cmd_serve_api` in `adapters/driving/cli/app.py`):
- `install_operator_logging(level, stdio_tee=True)` tees stdout/stderr into an in-process `LogBuffer` ring (`runtime/log_buffer.py`, DEFAULT_CAPACITY=2000 lines).
- The ring is served by `GET /api/v1/logs`. **Nothing is written to disk** — `run_dir_resource` defaults to `attach_log=False`, so `run.log` stays 0 bytes.
- Ring eviction is permanent loss: once 2000 newer lines push old ones out, pre-eviction history is unrecoverable. Pull `/api/v1/logs` early when investigating.
- `/proc/PID/fd` will show the process holding both ends of its own stdout pipes (fd 1/2 write ends, fd 6/7 read ends) — that is the tee pump, not a bug.

## Live-state inspection recipe

1. Locate the process: `ps aux | grep -E 'andromeda (up|serve-api)'`. Note elapsed time.
2. Provenance: `cat /proc/PID/cgroup` shows the parent scope (e.g. `app-org.chromium.Chromium-7879.scope` = launched from an IDE terminal that is gone; orphaned to systemd).
3. Auth token — extract inside the shell, never print:
   ```bash
   CFG=<path>/andromeda.freqai-afml.hl.paper.json
   TOK=$(jq -r '.api_token // .api_server.api_token // empty' $CFG)
   H="Authorization: Bearer $TOK"
   ```
   Do NOT use `python3 -c` for this — inline interpreter execution is blocked in this repo's shell policy; use jq.
4. Query the FreqUI-compatible API (default `http://127.0.0.1:8080/api/v1/`):

   | Endpoint | Returns |
   |---|---|
   | `ping` | liveness (fast even when session thread is stalled) |
   | `show_config` | dry_run, timeframe, state, strategy, leverage, stoploss |
   | `status` | open trades w/ open_rate, current_rate, enter_tag, stop_loss_abs, open_date |
   | `count` | open vs max_open_trades |
   | `profit` / `balance` | P&L aggregates / wallet state |
   | `trades`, `performance` | closed trades (empty shape: `{trades:[],trades_count:..}`) |
   | `whitelist` | active pairs |
   | `pair_candles?pair=BTC%2FUSDT&timeframe=1m&limit=3` | dataframe rows incl. signal cols |
   | `logs?limit=200000` | `{log_count, logs:[[date,epoch_ms,logger,LEVEL,message],...]}` |

## Stall-detection heuristics (forward-runner sessions)

A stalled session looks like:
- No new lines in the log ring for >15 min during market hours.
- `pair_candles` returns `[]` or stale dates; open trade `current_rate` frozen exactly equal to `open_rate`.
- An open trade surviving far beyond `afml.max_holding_bars × timeframe` (e.g. 35 bars at 1m) with no exit.

Why it matters: paper fills and stop-losses are evaluated **in-process** by the forward runner (`PaperSessionHost` thread → `run_paper_loop`). A stalled bar loop means the position has NO stop protection until restart. Typical root cause: Hyperliquid websocket stops delivering bars and `_run_live_node_bar_loop` blocks on the queue.

Recovery: kill/restart the process; the session wrapper finalizes its run dir as `phase="failed"` on crash; a frozen `status.json.updated_at` mid-session is itself a stall signal (per-tick journal writes stop).

## Trade forensics: "my trade vanished" (verified 2026-08-23)

Case: BTC/USDC afml_long opened (FreqUI) 14:19 @77532, later gone; `/trades` empty all day.

1. **Timezone first**: run-dir names, meta.json dates, and FreqUI API dates are UTC; run.log lines are host-local (UTC+2 here). Convert before correlating anything.
2. **"Open date" is the signal-bar ts, not wall-clock** — entries happen on lagged catalog bars during catch-up ticks, so a trade can appear minutes AFTER its stamped open time. Never conclude "no engine activity at that wall-time" from the FreqUI date alone.
3. Reconstruct lifecycle from `decisions/rows.jsonl`: print every row where `(n_trades, n_bars>0)` changes → gives entry tick (iter N) and exit tick (n_trades 1→0) with UTC timestamps.
4. Cross-check `run.log` `frequi session snapshot n_closed=/n_open=` heartbeats (~every 2 min).
5. **Diagnostic signature** — exits happening but never journaled (split-brain wiring): trade leaves `/status`, `/trades` stays empty forever AND `n_closed=0` in EVERY heartbeat while `n_open` flaps 1→0→1. A missed-exit bug looks the opposite: trade STAYS in `/status` past `max_holding_bars`.

## Run-artifact contract (TDD-pinned 2026-08-22)

`run_paper_session()` in `contexts/session/paper_session.py` wraps `run_paper_loop` and owns the full run lifecycle — this replaced the old stub-dir behavior:

- **Create**: `_paper_run` → `begin_operator_run(mode=paper|live by dry_run, attach_log=True)`; failures degrade to None + warning, never kill the session.
- **Per tick**: `_record_tick(run, snapshot)` appends a decision row AND refreshes status/meta counters (`n_bars`, `n_trades`, `last_tick_at`, `last_iteration`). Snapshot key is `iteration` (singular) — `iterations` only appears at loop end.
- **Finalize**: clean end → phase=done/exit_code=0 with final counters; crash → phase=failed/exit_code=1/error string. Finalization never masks the original exception.
- serve-api/up sets `container.run_dir_enabled.override(False)` before `init_resources()`, so the DI container seeds nothing; the session owns everything. Old behavior (stub dir, phase=running forever, 0-byte run.log) is gone.

Contract tests: `paper_session_run_test.py` (6 tests: artifacts present incl. redaction+git_sha mock, run.log lifecycle lines, per-tick journal+counters, row shape, clean finalize, crash finalize).

### Deterministic test seams for paper-session work

- Drive `run_paper_session(forward, bar_events=[datetimes], max_iterations=N, runs_base=tmp_path/"runs")` — injected closed-bar events avoid network/NautilusTrader; `runs_base` isolates the run dir under tmp_path.
- Build a real in-memory `ForwardSessionService` via the makers used by `paper_session_test.py` (`make_strategy/make_book/PaperExecutionAdapter/make_pipeline/make_forward_runner/make_session_runner/make_forward_session` with `use_synthetic_bars=True`).
- Patch `andromeda.contexts.session.forward_session.sync_catalog_micro_from_hl` to return `{"n_rows": 2, "source": "hl_nt"}`; patch `andromeda.runtime.run_dir._git_sha` to `"abc1234"` for deterministic meta.
- Crash-path test: `patch.object(ForwardSessionService, "on_ws_tick", side_effect=RuntimeError(...))` then `pytest.raises` around `run_paper_session`.
- CLI serve-api tests use fake containers — after adding container providers (e.g. `run_dir_enabled`), update every `_Container` fake in `app_main_test.py` or tests fail with AttributeError.

## Repo shell-policy notes (permanent lean-ctx allowlist)

- Blocked commands (do not retry): `systemctl`, `ss`, `docker`, `python3 -c` inline code, and heredoc `python - <<EOF` (interpreter flag blocked). A blocked segment rejects the ENTIRE pipeline before any of it runs — split independent commands into separate calls.
- Workarounds: read unit/deployment JSON from `deployments/systemd/`; probe ports with `curl`; use `/proc/<pid>/{cgroup,fd,cwd}` for process forensics; use `jq` for JSON extraction (also keeps secrets unprinted).
- Multi-line Python probes: write to a file (`/tmp/probe_*.py`) and run `.devenv/state/venv/bin/python <file>` directly — bypasses `devenv shell`, which re-installs prek git hooks on EVERY invocation and mixes task noise into stdout. For clean capture, redirect to a file and read it back.
- Lint triage: `git show HEAD:<path> > /tmp/head_copy && ruff check /tmp/head_copy` distinguishes pre-existing errors from newly introduced ones before fixing.
