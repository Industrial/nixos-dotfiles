# Multi-Pair Paper Session Attribution Defects (diagnosed 2026-08-25)

Operator report: "1. Only the first listed coin gets trades. 2. These trades
appear on all other coins/markets at exactly the same time in their charts.
3. None of the other coins/markets actually get trades."

Session: `andromeda up --config andromeda/configs/andromeda.freqai-afml.hl.paper.json`
(6 HL perps: BTC/ETH/HYPE/SOL/BNB/XRP vs USDC, 1m FreqAI AFML, dry_run).

## Root cause A — session pair-pinning (trading side)

- `python/andromeda/adapters/driven/acl/nautilus/paper_session.py:618`
  (`run_paper_loop`): `pair = pairs[0]` — every tick calls
  `_paper_ws_tick(forward, pair=pair, ...)` with the FIRST pairlist entry.
- `python/andromeda/services/runner/live_runner_service.py:480`
  (`_forward_tick`): `pairs_to_tick = [trigger_pair] if trigger_pair else universe`
  — so exactly one store gets `_refresh_store` → `on_bar` → `dispatch_bar`.
- The other five pairs are fully wired on the CAPTURE side:
  `build_hl_paper_live_node` subscribes bars/book/trades/mark/index/funding for
  every instrument with per-instrument `HlNtCaptureWriters`; `on_ws_tick`
  micro-syncs and warmup-gates ALL pairs. Only the DECISION dispatch is pinned.
- Warmup gate is all-pairs (`ready = iteration >= needed and not pending`) —
  once it passes, ticks flow but only to pairs[0].
- Origin: commit c5a68fa9 (2026-08-20) "introduce forward session architecture"
  built the loop around a single session pair; multi-pair WS capture arrived in
  the same lineage without re-wiring the trigger path.

## Root cause B — pair-blind chart overlay (display side)

- `python/andromeda/adapters/driving/http/app.py:565` (`/api/v1/pair_candles`)
  passes `self._chart_trades()` = the ENTIRE book (open + closed) unfiltered.
- `python/andromeda/adapters/driving/http/pair_ohlcv.py::overlay_trade_signals`
  buckets EVERY trade's open/close ms timestamps onto the requested chart via
  `_bucket(ts)`; it never reads `trade["pair"]`. Its nearest-bar fallback
  (`nearest = min(bar_starts, key=...)`) even paints trades whose timestamps
  fall OUTSIDE the loaded window onto some candle — hence "exactly the same
  time" marks on charts that share no data window with BTC.
- Trade serialization itself is correct: `trade_to_ft_dict` emits each trade's
  own `pair` (adapters/driven/acl/freqtrade/serialize.py).

## Live evidence (probed the running bot's REST API, 2026-08-25)

Auth: Bearer token from config (`api_server.api_token`), Basic fallback
(`username/password`). Probes:

```
GET /api/v1/trades
  -> 6 trades, Counter({'BTC/USDC': 6})        # symptom 1 confirmed

GET /api/v1/pair_candles?pair=<P>&timeframe=1m&limit=300
  count enter_long/exit_long/enter_short/exit_short across rows:
  ETH/USDC {n_rows:300, 3,3,4,3}
  SOL/USDC {n_rows:300, 3,3,4,3}
  HYPE/USDC {n_rows:226, 3,3,4,3}   # fewer candles, SAME marks -> copied
```

Byte-identical signal counts on pairs with different candle counts = overlay
copies BTC trades; NOT evidence that those markets traded. Run-dir journal
corroborated: decisions/rows.jsonl n_trades=7 flat across iterations while
n_bars grew ~1/tick (only one store advancing).

## Distinguishing "bot did X" from "charts show X"

- Truth of record: `/api/v1/trades`, `/api/v1/status`, `/api/v1/count`,
  decisions/rows.jsonl.
- Display surface: `/api/v1/pair_candles` + `/api/v1/pair_history`
  (signal columns are OVERLAYS computed at request time).
- FreqUI renders chart markers from pair_candles overlays — a display bug here
  looks exactly like a strategy bug ("trading coins I never configured").

## Shipped fix (2026-08-25, TDD RED→GREEN, uncommitted at session close)

1. paper_session.py — pinning REMOVED: `run_paper_loop` no longer binds
   `pair = pairs[0]`; `_paper_ws_tick` signature is now
   `pair: str | None = None` and the live tick passes `pair=None`, so
   `_forward_tick` fans out to the full universe (`trigger_pair=None`
   branch). Synthetic bar_events append to EVERY pair. The LiveNode factory
   still receives `pairs[0]` as its primary bar type (capture-side only).
   Snapshot key `"pair"` kept as `pairs[0]` for display compatibility.
2. pair_ohlcv.py — `overlay_trade_signals(..., pair=...)`: trades whose
   `trade["pair"] != pair` are skipped BEFORE bucketing; `pair_history_body`
   threads the requested pair through (pair_ohlcv.py:523). Default
   `pair=None` preserves legacy behavior for backtest overlays whose trade
   dicts carry no pair.
3. Regression tests (both RED on unfixed code, GREEN after):
   - paper_session_test.py::test_run_paper_loop_ticks_every_pair_not_only_first
     (2-pair config → bar dispatch reaches BOTH stores; asserts via
     `len(forward.stores[...]) == 2`)
   - pair_ohlcv_test.py::test_overlay_trade_signals_skips_other_pairs_trades
     (ETH trade never paints on BTC/SOL frames)
4. Verification shape: scoped battery over the six touched/adjacent test
   modules (paper_session, pair_ohlcv, app, session, frequi_backtest,
   live_runner_service tests) — 97 passed exit=0; ruff findings proven
   pre-existing via line-for-line identical locations HEAD vs worktree.
5. Restart required for effect (not done — analyze-only): old process keeps
   trading pairs[0]-only with mirrored chart marks until bounced.

### Edit-tooling pitfall from this session

lean-ctx `ctx_patch` batch ops require per-op `"op"` keys (a bare list of
replace payloads is rejected), and its `insert_after` needs an ANCHORED read
(`ctx_read mode="anchored"` supplies the N:hh hash). Anchored inserts can
land one line off when the anchor is a repeated def line — after any such
edit, re-read the region and repair duplicates immediately (this session:
an inserted test header briefly duplicated a neighboring def; two small
anchored `replace_lines` fixed it). Native `patch` remains fine for plain
unique-string replaces in these files.

## Reusable probes

```bash
# trades by pair
curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/v1/trades \
  | grep -oE '"pair": "[^"]*"' | sort | uniq -c

# per-chart signal counts (throwaway script; python3 -c blocked in ctx_shell)
for P in BTC/USDC ETH/USDC SOL/USDC; do ...count enter_*/exit_* columns...; done
```

Note: `python3 -c` inline is permanently blocked in ctx_shell — write the probe
to a `/tmp/hermes-verify-*.py` file, run it, delete it.
