---
name: strategy-portfolio-loop
description: >-
  Continuous research loop for a multi-strategy trading portfolio: diagnose the
  current book, choose the highest-EV next action (hyperopt, invent, rebalance,
  retire), prove sleeves under varied markets/timeframes/regimes, then promote
  only via portfolio-level aggregate backtests. Use when improving the strategy
  portfolio, selecting the next research step after a single-algo result,
  rebalancing sleeves, retiring weak strategies, designing a new algo for the
  book, or running/interpreting portfolio backtests (portfolio/*.toml,
  scripts/portfolio_backtest.py).
---

# Strategy Portfolio Loop

Never-ending search for a **better-balanced portfolio of algorithms**. A single
profitable backtest is a candidate sleeve — not a finished product.

## North star

Maximize **portfolio** risk-adjusted return and **diversification of failure modes**,
not the sum of in-sample sleeve P&Ls.

## When to invoke

- Slash commands: `/strategy-portfolio-loop` or `/portfolio-loop`
- After any hyperopt / new strategy / walk-forward result
- User mentions portfolio, sleeves, rebalance, retire, diversify, next research step
- Before promoting any algo to paper/live capital

## Operating loop (one cycle = one measurable improvement)

Run in order. Stop when the cycle's acceptance bar fails — do not "hope forward."

```
1. DIAGNOSE   → current portfolio state + weakest link
2. DECIDE     → one action class (see Action Menu)
3. PROVE      → multi-market / multi-TF / multi-regime tests
4. INTEGRATE  → portfolio aggregate backtest vs prior baseline
5. COMMIT     → update portfolio/*.toml + record in runs/portfolio/
6. REPEAT
```

### 1. Diagnose

Load `portfolio/*.toml` (active book). For each sleeve note: status, markets,
timeframes, last OOS metrics, pairwise return correlation, contribution to
portfolio max DD.

Identify the **bottleneck** (pick one):
- Concentration (one sleeve / one market drives PnL)
- Correlation (sleeves move together in stress)
- Fragility (edge dies OOS or off-champion TF)
- Capacity (too few trades / too sparse for capital)
- Drag (sleeve lowers portfolio Sharpe/Calmar)

### 2. Decide — Action Menu

Choose **exactly one** primary action this cycle. Score Impact×Effort; prefer
quick wins that raise portfolio metrics.

| Action | Use when | Forbidden when |
|--------|----------|----------------|
| **Hyperopt sleeve** | Clear structural knobs; sparse or unstable IS | Same window already mined; no OOS plan |
| **Walk-forward / OOS** | IS looks good; promotion pressure | No champion family yet |
| **Multi-market / multi-TF bench** | Single-market hero narrative | Data missing for targets |
| **Invent new strategy** | Book lacks an uncorrelated return driver | Existing sleeves unproven OOS |
| **Reweight** | Correlations known; capital misallocated | Stats from <1 comparable window |
| **Retire / replace** | Sleeve fails gates or duplicates another | Emotional attachment; no replacement candidate |
| **Portfolio aggregate rerun** | Sleeve set or weights changed | Individual sleeve runs stale/broken |

Second-order check (mandatory): *"And then what if this action succeeds?"*
Reject actions that improve one sleeve while increasing portfolio drawdown
correlation or research overfitting.

### 3. Prove — evidence gates (sleeve)

A sleeve may enter **candidate** status only if it clears **all**:

1. **Sample**: min trades and calendar span (see [reference.md](reference.md))
2. **OOS**: ≥1 held-out window; params frozen before peek
3. **Markets**: ≥3 symbols **or** explicit single-name mandate with documented reason
4. **Timeframes**: primary TF + at least one alternate (or justify monogamy)
5. **Regimes**: report bull / bear / chop slices when history allows
6. **Costs**: same fee/slippage/funding model as production sim
7. **Deflated / multiplicity**: acknowledge trial count (AFML DSR or honest caveat)

Fail any gate → stay in **research**; never write into active portfolio weights.

### 4. Integrate — portfolio aggregate

Representation: `portfolio/<name>.toml` lists sleeves; each sleeve is one
backtest bundle (strategy × config × markets × TF × window).

Run:

```bash
devenv shell -- python scripts/portfolio_backtest.py \
  --portfolio portfolio/baseline_v0.toml
```

Model (explicit, honest):
- Capital is **partitioned** by sleeve weight (independent sim pools)
- Portfolio equity[t] = Σ weight_i × normalized_sleeve_equity_i[t]
- This is **not** shared-margin multiplexing; it is the baseline accumulation
  of sleeve backtests. Document that limitation in every report.

Acceptance for baseline bump:
- Portfolio Sharpe or Calmar ↑ **and** max DD not materially worse
- Mean pairwise sleeve return correlation below threshold **or** intentional hedge
- No sleeve with weight>0 that fails candidate gates

### 5. Commit

On accept:
1. Update `portfolio/<name>.toml` (weights, statuses, notes)
2. Keep artifact under `runs/portfolio/<ts>/`
3. One-paragraph changelog: bottleneck → action → evidence → portfolio delta

On reject: leave baseline unchanged; log why in the run dir.

## Anti-patterns

- Promoting on one month / one market / one TF
- Optimizing sleeve IS return while portfolio DD correlation rises
- Keeping a sleeve because it was hard to build
- Calling equal-weight sum of cherry-picked runs a "portfolio backtest" without a manifest
- Inventing a new strategy before exhausting OOS on the current bottleneck sleeve

## Repo hooks

| Artifact | Role |
|----------|------|
| `portfolio/*.toml` | Active book definition |
| `scripts/portfolio_backtest.py` | Run sleeves + aggregate |
| `scripts/portfolio_aggregate.py` | Aggregate existing run dirs only |
| `runs/portfolio/<ts>/` | Immutable cycle artifacts |
| `syo_*.toml` | Per-strategy execution configs |

Details, gates numbers, status machine: [reference.md](reference.md).
