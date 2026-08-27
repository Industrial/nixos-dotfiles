# QuestDB Storage Migration + TDD Session Notes (2026-08-22)

Session-specific detail backing the "QuestDB-First Data Storage" and "TDD
Conventions" sections of SKILL.md. Repo: solana-yield-optimizer (Andromeda).

## 1. The parquet→QuestDB migration (what was wrong and how it was fixed)

### Finding
Raw market data already went to QuestDB, but derived micro features still went
to parquet on every paper-session tick:
- `hl_micro.py` → `sync_catalog_micro_from_hl` called `write_catalog_micro`
- `micro_features.py:129` → `frame.write_parquet(path)`
- Live evidence: log line `wrote catalog micro path=.../micro/BTC_USDT_1m.parquet`

### Fix (files touched)
| File | Change |
|---|---|
| `adapters/questdb/rows/md_micro.py` | New row: timestamp, instrument_id, source, venue, features_json (JSON column), ts_init_ns, ingest_run_id, schema_version |
| `adapters/questdb/rows/__init__.py` | Export MdMicroRow |
| `repositories.py` | INSERT_MICRO_SQL / SELECT_MICRO_SQL / MicroRepository (mirror OiRepository shape) |
| `catalog_store.py` | Facade `write_micro(rows, pair=, timeframe=, venue=)` tags instrument_id via `questdb_instrument_id`; `load_micro(...)` |
| `testing/memory_store.py` | In-memory double with same methods; drops non-finite values; accepts rows or dicts |
| `hl_micro.py` | Sync builds MdMicroRow list (`json.dumps(features, allow_nan=False)`) and calls `store.write_micro`; stats gain `storage="questdb"`, keep `source="hl_nt"` for compat |
| `micro_features.py` | `load_catalog_micro(venue="hl", questdb_store=None)` — QuestDB-first read |

### Read-semantics subtlety (cost two debug rounds — get it right first)
- Explicitly passed store ⇒ authoritative even if empty (test asserts empty wins over stale parquet).
- No store passed ⇒ try auto-discovery via `require_questdb_store()`; if discovery succeeds but table is empty, fall back to parquet (offline tools like the CME MarketTaS path depend on this).
- Memory-store doubles must tolerate both row objects and plain dicts; tests pass dicts with a `features` key while production passes `features_json`.

### Instrument-id gotcha
`questdb_instrument_id("SOL/USDC", venue="hl")` → `SOL-USD-PERP.HYPERLIQUID`.
Don't assert `.endswith(".HL")` in tests; use the mapper or the full id.

## 2. TDD workflow that worked (reusable pattern)

1. RED: contract test fails with the honest reason (e.g. missing kwarg / AttributeError).
2. GREEN minimal: implement adapter + facade + memory double together.
3. Iterate on failures — each failure named the next missing piece.
4. Then wire PRODUCTION paths and update their tests.
5. Full suite of every touched context.

### Pitfalls hit (all real, all cost iterations)
- **MagicMock stores silently drop writes**: sync "succeeded" but round-trip read returned []. Use `MemoryQuestDbStore` whenever asserting write→read.
- **`iteration` vs `iterations`**: tick snapshots carry `iteration`; loop result carries `iterations`.
- **Timestamps from polars are ISO strings**, not datetimes: parse with `datetime.fromisoformat`, handle naive→UTC.
- **MdMicroRow requires `ingest_run_id`** (no default on that field) — pass `"andromeda"` when constructing outside the facade.
- **Legacy tests encode old contracts**: `stats["source"] == "hl_nt"` and parquet round-trip assertions needed updating, not deletion. Prefer updating to preserve coverage.
- **CLI fake containers**: `_cmd_serve_api` touches api_token, raw_config, session.venue, run_dir_enabled — fakes missing any fail with an AttributeError that looks unrelated. Check what the command touches before assuming your change broke a CLI test; also verify against HEAD (`git worktree add /tmp/head HEAD`) because WIP files may contain pre-existing failures.

## 3. Live-data crash found by post-deploy verification (2026-08-22)

The migration tests passed on synthetic data; the FIRST real 50-pair run
crashed the session thread:

```
ValueError: Out of range float values are not JSON compliant: nan
  hl_micro.py: json.dumps(features, allow_nan=False)
```

Real HL book/ctx gaps produce NaN micro features (e.g. `depth_ratio_5` when
one side is empty). Fix: filter non-finite values BEFORE building the features
dict — `if row[c] is not None and math.isfinite(float(row[c]))`. This matches
lookup semantics (they already skip non-finite), so nothing is lost. Contract
test: `hl_micro_nan_test.py` (sync with funding/OI absent → row persists with
only finite features). Lesson: `allow_nan=False` is a crash-at-write-time
tripwire, not validation — filter at the source. Also: the crash was only
visible because status.json showed `phase=failed` with the error string — the
run-artifact contract paying off immediately.

## 4. Environment notes (session-transient, verify before relying)
- `devenv shell -- python -m pytest ...` works but re-runs prek hook install each time (noisy output, slower). Direct venv python is faster for probes.
- Script stdout can be swallowed under devenv+tee interactions; redirect to a file inside the command and read the file.
- Shell allowlist blocks: systemctl, ss, docker, python3 -c, heredoc-python. jq/curl//proc forensics are available.
