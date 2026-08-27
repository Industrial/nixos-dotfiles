# Flow-Momentum Lag-Gate Study (CME MES, 2026-08-24)

Full numbers behind the "Microstructure signals: the lag gate" section of
SKILL.md. Reproduce with `python/andromeda/research/flow_momentum_study.py`
primitives; raw probes were throwaway /tmp scripts (not kept).

## Data

- Source: QuestDB `md_l2` / `md_trade` / `md_bar`, instrument_id
  `MES-USD-PERP.CME`, imported from MarketTaS day folders.
- At study time: 17–18 sessions imported (~6.2M l2 rows, ~2.7M trade prints,
  230,560 1m bars). Tick = 0.25 pts; median price ≈ 6500 → RT cost ≈ 0.72 bp.

## Baseline stats (bars)

- vol_1m_annualized ≈ 20.2%; excess kurtosis ≈ 1126 (fat tails); skew −4.17;
- zero-return share 11.5%; acf1 −0.015, acf5 −0.005 (no bar momentum).
- Intraday vol U-shape in UTC: peak hours 22:00–23:59 (7.7/5.8 bp per-min σ),
  trough 03:00–06:59 (~1.3 bp). CME RTH opens line up with the 14:00–15:59 hump.

## Signal under test

- `net_t` = Σ signed aggressor volume (buy +, sell −) within minute t
- `sig_t` = rolling_sum(net, 5 minutes); z = sig scaled by daily max |·|
- Event: |z| ≥ threshold, non-overlapping (15-min min gap), direction = sign(z)
- Costs: full round trip charged per event.

## Results — why IC ≠ tradable

1. **IC**: Spearman(sig_t, fwd_ret_{t→t+1}) mean +0.1668, sd 0.031, t = 22.2,
   hit rate 17/17 days. First half +0.165 vs second half +0.169 (stable!).
2. **Quintiles** (pooled, within-day ranks): Q1 −39.5 ppm/min → Q5 +40.3
   ppm/min, monotone. Q5−Q1 spread ≈ 0.80 bp/min > 0.72 bp RT cost — looked
   viable ON PAPER.
3. **Event backtest, realistic fills** (entry next-bar close, hold 10m):
   thresh 0.3 → −84bp total (167 trades); 0.5 → −70bp (77); 0.7 → −53bp (30).
   Negative at EVERY threshold, both halves of the window.
4. **Timing decomposition** (thresh 0.5, hold 5m):
   - entry at decision-bar close: **+81bp (+1.05/trade)**
   - entry at NEXT-bar close: **−69 to −84bp (−0.87/trade)**
   - signal recomputed with prints lagged +30s before bucketing: edge gone
     (hold 5m: −0.87/trade; hold 10m: +0.03/trade — noise).

## Interpretation

The entire apparent edge lives INSIDE the final seconds of the decision bar:
flow that arrives during minute t predicts the remainder of minute t's return,
which is only "capturable" if you can fill at a price that already includes it.
This is same-minute lookahead — an artifact of evaluating on bar-close prices
with bar-close decisions. The strong IC stability across days and halves makes
it MORE dangerous, not less: every conventional robustness check passes while
the economics are fake.

## Rule (the lag gate)

Before calling any intrabar-derived signal tradable, event PnL must agree
across:

(a) decision-bar-close entry,
(b) NEXT-bar entry,
(c) signal recomputed with ≥30s decision lag.

Only (b)/(c) count as evidence. A signal where (a) >> (b)≈(c) is lookahead.

Reusable implementation: `python/andromeda/research/flow_momentum_study.py`
(`signed_flow(decision_lag_seconds=)`, `event_pnl(entry_lag_bars=)`,
`lag_gate(...)`) with colocated tests pinning the gate semantics on synthetic
momentum worlds. Commit feb25e91.

## Related operational lesson

`CatalogService.download_micro` accumulates the whole window before writing —
a multi-month book_l2 request OOM'd (>15 GB RSS, 0 rows written). Batch one
session-day per invocation (~2 min/day for MES); bars dedupe via
`_existing_bar_ts`, so overlapping re-runs are safe. Watch signature: process
at 90%+ CPU, RSS climbing, md_l2/md_trade counts frozen at 0.
