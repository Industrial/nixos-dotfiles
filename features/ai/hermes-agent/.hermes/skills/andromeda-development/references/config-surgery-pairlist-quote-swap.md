# Config Surgery: Pairlist/Instrument/Quote-Asset Rewrites (2026-08-22)

Session record of rewriting `andromeda/configs/andromeda.freqai-afml.hl.paper.json`
programmatically: pruning 5 dead pairs (BONK, GRT, MANA, MKR, PEPE) and converting
USDT → USDC across pairlist, instruments map, and stake_currency.

## What went wrong on the first pass

The rewrite script filtered dead pairs out of the pairlist and rebuilt the instruments
map from the pruned list — but the ORIGINAL instruments map contained entries that were
never in the original pairlist (`ENS`, `MARK`). Because the rebuild iterated only over
the final pairlist's *sources* (old pairlist minus dead), the orphan keys survived.

Result: `set(pairlist) != set(instruments.keys())` — 45 pairs vs 47 instrument keys.
A config consumer iterating instruments would subscribe pairs the trading loop never
ticks; one iterating pairlist would silently ignore configured instruments.

## Correct procedure

```python
DEAD = {"BONK/USDT", "GRT/USDT", "MANA/USDT", "MKR/USDT", "PEPE/USDT"}
pairs = [p for p in cfg["pairlist"] if p not in DEAD]
cfg["pairlist"] = [f"{p.split('/')[0]}/USDC" for p in pairs]
cfg["instruments"] = {p: cfg["instruments"][p] for p in cfg["pairlist"]}  # derive FROM final list
cfg["stake_currency"] = "USDC"
```

Key rule: **rebuild dependent maps from the final authoritative list**, never filter
the old map. Orphan keys are invisible until you diff both directions.

## Verification gate (throwaway script pattern)

No canonical suite covers operator-config JSON content. Gate rewrites with a
`/tmp/hermes-verify-*.py` script asserting:

1. Expected pair count after prune.
2. Zero references to the old quote asset anywhere in the raw file text
   (`raw.count("USDT") == 0`) — catches stragglers grep-by-eye misses.
3. `set(pairlist) == set(instruments.keys())` — BOTH directions.
4. Dead base assets absent from the pairlist.
5. Every instrument id well-formed (endswith `-USD-PERP`, non-trivial length).
6. `stake_currency` updated; unrelated flags preserved (`dry_run is True`).
7. Every pair's quote leg equals stake_currency.

Run it, read failures as defects in the REWRITE (not noise), fix the script's logic,
re-run, then delete the script. Exit code is the gate.

## Final state achieved

45 pairs / 45 instruments, exact key match; stake USDC; dry_run preserved;
zero USDT substrings. Config verified before any process restart consumed it.
