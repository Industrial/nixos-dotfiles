# Partial-Failure Tolerance & Config Validation Fixes (2026-08-22)

Session where four bug classes from the paper-session bug hunt were fixed TDD-style.
Ledger: `history/2026-08-22T222500Z-paper-session-bug-hunt.md`.

## BUG-AVAIL-01 — conjunctive readiness gate (Critical)

Before: `forward_session.on_ws_tick` required ALL pairs ready:
`ready = iteration >= needed and not pending` — one dead pair blocked trading forever.

Fix: `_excluded_pairs(universe, micros, needed, now, session_start)` — pairs with
zero micro rows after `_EXCLUDE_AFTER_MINUTES = 45.0` grace are excluded; `pending`
filters them out; gate runs over active pairs only. Exclusion list surfaces in the
warming snapshot + log line so operators see what was dropped and why.

Key design choice: exclusion requires BOTH zero rows AND elapsed grace — a slow
pair that is still accumulating is never excluded, only provably-dead ones.

## BUG-OBS-04 — truthful warmup metrics

`_warming_metrics(universe, micros, excluded, needed)` returns
`{ready_pairs, active_pairs, total_pairs, excluded_pairs, warmup_pct}`.
`warmup_pct` = sum(rows of active pairs) / (len(active) * needed), capped 100.
Replaced the meaningless `iter=2286/175` log form with
`[paper] warmup R/A pairs ready (P%) pending=... excluded=...`.
Snapshot payload now embeds the dict as `warmup:` for FreqUI consumption.

## BUG-DATA-03 — stream staleness surfacing

`sync_catalog_micro_from_hl` stats now include `last_row_age_min` (age of newest
micro row vs wall clock) and `stale: bool` (>10 min). Log line includes the age.
This makes an MKR-style context-feed death (L2 flowing, mark/index silent)
visible within one tick instead of "hl micro empty" forever. Root-cause tool:
per-instrument `min/max(timestamp)` across md_* tables — earliest-stopped feed wins.

## BUG-CFG-07 — config validator

New `andromeda/configs/validate_paper_config(cfg) -> list[str]` (empty list = valid):
- pairlist keys == instruments keys, both directions (orphans caught)
- instrument ids well-formed `*-USD-PERP`
- every pair's quote leg == stake_currency
- base in `KNOWN_DEAD_BASES` (BONK/GRT/MANA/MKR/PEPE) → error (regression guard)
Five contract tests incl. one asserting the LIVE config validates clean.
Wire point if desired later: call it in `create_container` / CLI startup to fail fast.

## Test patterns that mattered

- RED first: import errors (`_excluded_pairs` not found) proved missing implementation.
- Metric assertion trap: compute expected values by hand before asserting —
  `warmup_pct` for {A:180, B:50} over needed=175 is 225/350 = 64.3% (rows sum,
  capped per-pair at needed happens naturally since extra rows still count in the
  numerator). Asserting a guessed number burned two cycles; derive it from the
  formula in the test comment instead.
- Staleness test uses real timestamps relative to `datetime.now(UTC)` — no mocks.
- After fixes: full session+catalog+configs+execution sweep = 322 passed, 8 skipped;
  ruff clean except pre-existing HEAD I001s (verify via stash round-trip).
