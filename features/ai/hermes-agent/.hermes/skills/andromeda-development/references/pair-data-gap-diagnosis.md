# Diagnosing "no data for pair X" in the Andromeda HL paper session

Session-proven recipe (2026-08-22, 50-pair run). Read-only — no restarts needed.

## Step 1 — Establish what "no data" means before diagnosing

Three distinct failure signatures, each with a different cause:

| Signature | Meaning | Where seen |
|---|---|---|
| `hl micro empty venue=hl pair=X` every tick | Bars/book arrive but the Depth10+mark+index join can't complete | run.log |
| `instrument not found in cache: X-USD-PERP.HYPERLIQUID` | The instrument ID doesn't exist on Hyperliquid via this adapter — subscribe rejected | nautilus.stderr in run.log |
| Pair absent from `populate_indicators pair=X` lines entirely | Store never became ready → strategy never invoked for it | run.log |

Also check the user isn't looking at the wrong symbol suffix: config pairs are
`/USDT` (mapped to `X-USD-PERP.HYPERLIQUID`). A `/USDC` filter shows nothing.

## Step 2 — Ground truth from QuestDB (not logs)

```python
# /tmp/q_pairs.py — run with repo venv, QUESTDB_PG_URL set
from andromeda.contexts.catalog.adapters.questdb.client import QuestDbClient
client = QuestDbClient.from_env()
with client.connect() as conn, conn.cursor() as cur:
    cur.execute("SELECT instrument_id, count(*) FROM md_bar GROUP BY 1")
    bars = {r[0].split("-USD-PERP")[0] for r in cur.fetchall()}
    cur.execute("SELECT instrument_id, count(*) FROM md_l2 GROUP BY 1")
    l2 = {r[0].split("-USD-PERP")[0]: r[1] for r in cur.fetchall()}
    cur.execute("SELECT instrument_id, count(*) FROM md_mark GROUP BY 1")
    mark = {r[0].split("-USD-PERP")[0]: r[1] for r in cur.fetchall()}
```

Interpretation matrix (per pair):
- `md_bar>0` → healthy, trading-capable once ≥175 rows.
- `md_l2>0, md_mark==0 or frozen timestamp` → context feed gap. Micro join needs
  Depth10 AND mark AND index per bar close; one missing leg = "hl micro empty"
  forever even though the book streams. Compare `min/max(timestamp)` of md_l2 vs
  md_mark to spot a stream that died at startup (MKR case: L2 ran 3h, mark froze
  after 15 min).
- all zero + "instrument not found" → not listable via this adapter path; prune.

## Step 3 — Log forensics for per-pair progress

```bash
R=$(ls -t notebooks/runs/andromeda/paper/ | head -1)
grep "populate_indicators pair=$P/" $R/run.log | tail -1   # bars=N — real progress
grep 'forward collecting' $R/run.log | tail -1             # iter=M/175 is TICKS not bars
```

The `pending_micro=[...]` list printed each tick is the FULL universe snapshot,
not a failure list — pairs still appear there while healthy and warming.

## Step 4 — Classify and report

Report as a table: group / count / pairs / cause / action. Typical 50-pair outcome:
45 collecting normally, 4 unlistable (subscribe-fail), 1 context-feed gap.
Effective trading universe = pairs with md_bar flowing; recommend pruning dead
pairs from `pairlist` only when user authorizes changes.
