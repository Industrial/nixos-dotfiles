# 50-Pair Paper Session Run — 2026-08-22

Operational log of scaling the HL paper session to 50 pairs, with the
monitoring recipe and warmup timeline. Companion to SKILL.md
"Operational Inspection" and "Paper/Backtest Exit Parity" sections.

## Config changes (andromeda.freqai-afml.hl.paper.json)

- pairlist: 10 → 50 USDT perps; `max_open_trades: 50`; `dry_run_wallet: 100000`
- Keep `instruments` map in sync with pairlist — every entry needs an
  `X/USDT → X-USD-PERP` mapping or the WS subscribe fails for it.
- Reality check: only ~45 of the 50 IDs resolve on Hyperliquid. Subscribe
  failures (`instrument not found in cache`) identify dead pairs — prune them.

## Startup sequence (each step fixes a distinct crash)

1. `QUESTDB_PG_URL=postgresql://admin:quest@127.0.0.1:8812/qdb` MUST be in the
   bot's env (session thread crashes otherwise, HTTP API still serves).
2. `deployments/questdb/schema.sql` must be applied before any run that writes
   md_micro (apply via PGWire script executing the whole file — all statements
   are CREATE TABLE IF NOT EXISTS / idempotent). Missing table = psycopg2
   "table does not exist [table=md_micro]" and a dead session thread.
3. NaN-hardened serializer must be present (see SKILL.md QuestDB section).

Launch pattern:

```bash
QUESTDB_PG_URL=postgresql://admin:quest@127.0.0.1:8812/qdb exec \
  .devenv/state/venv/bin/python -m andromeda up \
  --config andromeda/configs/andromeda.freqai-afml.hl.paper.json \
  --host 127.0.0.1 --port 8080 --log-level INFO
```

Run from `python/` workdir (relative catalog root resolves there).

## Monitoring recipe (read-only)

```bash
R=$(ls -t notebooks/runs/andromeda/paper/ | head -1)
cat notebooks/runs/andromeda/paper/$R/status.json        # phase/n_bars/n_trades/updated_at
ps aux | grep 'andromeda up' | grep -v grep              # aliveness
grep 'forward collecting' .../$R/run.log | tail -1       # iter=N/175 (ticks, not bars!)
grep 'wrote md_micro venue=hl pair=SOL' .../$R/run.log | tail -1   # rows=M → real bar count
grep 'hl micro empty' .../$R/run.log | tail -40 | grep -oE 'pair=[A-Z]+/USDT' | sort | uniq -c
CFG=<config>; TOK=$(jq -r '.api_server.api_token' $CFG)
curl -H "Authorization: Bearer $TOK" http://127.0.0.1:8080/api/v1/count
curl -H "Authorization: Bearer $TOK" http://127.0.0.1:8080/api/v1/profit
```

Watchdog cron (local-only delivery on CLI): every 10m × ceil(warmup_min/10 + slack),
prompt checks pid alive, status.json freshness, API count/profit; reports one line.
View outputs with cronjob(action='list'). No live delivery channel on CLI sessions.

## Warmup timeline observed

- Start → first md_micro writes: <2 min
- Bar accrual rate: exactly ~1 bar/min/pair (websocket closed bars)
- 72 bars at T+70min; projected trading start ≈ 175 min after start (~20:55 UTC)
- Iteration counter hit 1143 while bars were 72 — ticks ≠ bars, always use rows=
- FreqAI training lines (`FreqAIHost.train begin`) appear only AFTER a pair
  crosses 175 micro rows; `populate_indicators` runs during collection too, so
  its presence is NOT evidence of warmup completion.

## Crash forensics value

Each failed startup produced a finalized run dir with full traceback in
run.log and status.json exit_code=1 (the run-artifact contract paying off):
- QUESTDB_PG_URL missing → CatalogError at build_hl_paper_live_node
- md_micro missing → psycopg2.DatabaseError at write_micro
- NaN features → ValueError at json.dumps(allow_nan=False)
Diagnosing "why did the bot die" = read newest run.log traceback, not process
stdout.
