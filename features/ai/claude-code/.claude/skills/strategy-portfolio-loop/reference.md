# Strategy Portfolio Loop — Reference

## Sleeve status machine

```
research → candidate → active → retired
                ↓
             rejected
```

| Status | Meaning | Capital weight |
|--------|---------|----------------|
| `research` | Exploring; may be IS-only | 0 |
| `candidate` | Cleared evidence gates; awaiting portfolio integrate | 0 (or shadow) |
| `active` | In baseline portfolio weights | >0 |
| `rejected` | Failed gates; keep for autopsy | 0 |
| `retired` | Was active; removed for cause | 0 |

## Default evidence thresholds

Tune per strategy family, but do not silently loosen.

| Gate | Default |
|------|---------|
| Min closed trades (IS window) | 30 (scalpers may use 50; slow swing 15 with longer span) |
| Min calendar span | 60 trading days across combined windows |
| OOS windows | ≥1 contiguous held-out block ≥20% of IS span |
| Markets | ≥3 HL perps unless `mandate = single_name` |
| Alternate TF | ≥1 besides champion |
| Profit factor (OOS) | ≥1.1 |
| Max DD (OOS) | Report; hard-fail if worse than 2× portfolio DD budget |
| Pairwise corr (daily ret) | Flag if \|ρ\| > 0.6 vs an existing active sleeve |

## Portfolio manifest schema

```toml
schema_version = 1
name = "baseline_v0"
initial_capital = 100000.0
vendor = "hyperliquid"
# equal | explicit (use sleeve.weight)
allocation = "explicit"
from = "2026-06-27T00:00:00Z"
until = "2026-07-27T00:00:00Z"
notes = "..."

[[sleeves]]
id = "sr_hype_1h"
strategy = "sr"                 # CLI --strategy value
config = "syo_sr_hype.toml"     # repo-relative
timeframe = "1h"
warmup_candlesticks = 200
weight = 0.34
status = "candidate"            # research|candidate|active|rejected|retired
# markets omitted → use [markets] inside config
# markets = ["HYPE-PERP"]
# reuse_run = "runs/2026-07-27_backtest_..."  # optional skip re-exec
notes = "hyperopt champion family; OOS pending"
```

## Aggregation math

For sleeve i with weight w_i (Σ w = 1 over active/candidate included in the run):

1. Load `equity_curve.csv` → series E_i(t)
2. n_i(t) = E_i(t) / E_i(t0)           # growth factor
3. sleeve_capital_i = W0 * w_i
4. V_i(t) = sleeve_capital_i * n_i(t)
5. V(t) = Σ V_i(t) on a common grid. Default `align=asof_coarse`: master = coarsest median bar spacing; each sleeve mapped with backward-asof. `intersection` available for identical grids.

Metrics on V(t): total return, max DD, Sharpe (bar returns annualized by TF),
per-sleeve contribution, pairwise correlation of bar returns.

## Cycle output checklist

`runs/portfolio/<ts>/` must contain:

- `manifest.copy.toml` — portfolio definition used
- `sleeves.json` — per-sleeve run paths + stats
- `portfolio_equity.csv` — aggregated V(t)
- `stats.json` — portfolio metrics
- `correlation.json` — pairwise sleeve return correlations
- `report.html` — human summary
- `decision.md` — bottleneck, action, accept/reject

## Inventing a new strategy (portfolio-aware)

Only if diagnose says the book lacks a return driver orthogonal to actives.

Brief before coding:
1. Economic hypothesis (who pays you?)
2. Expected correlation vs each active sleeve
3. Failure mode (when it dies)
4. Minimum markets/TFs for proof
5. Kill criteria

Then implement → unit tests → single-market smoke → full Prove gates → Integrate.
