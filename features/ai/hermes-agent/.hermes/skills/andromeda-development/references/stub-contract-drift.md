# Stub/Fixture Contract Drift — Silent Starvation Through Data-Source Doubles

Case study from the 2026-08-23 bug-squash sweep (item: `markettas_datasource.py`),
generalizable to any stub whose output frames are consumed by production code.

## What happened

`contexts/catalog/adapters/providers/markettas_datasource.py` (the MarketTaS
filesystem stub) built its `bests` Polars frame with columns
`timestamp / price / volume`. Its ONLY production consumer,
`CmeBookProvider.fetch` in `providers/cme.py`, reads
`Bid Price / Ask Price / Bid Volume / Ask Volume` via
`row.get("Bid Price") ... if None: continue`. Result: every row silently
dropped, book stream permanently empty, no error anywhere.

Same failure family as the paper-session incident: individually-correct pieces,
bug lives in the seam.

## Why every test stayed green

- `cme_test.py` monkeypatches `MarketTaSDataSource` with its own `_DS` double
  that uses the CORRECT columns — so the consumer was tested against a
  hand-written bundle, never the real stub.
- Nothing imported/exercised the real stub end-to-end (it had no test file).
- Lesson: isolated-correct + no integration test = seam bugs survive full green suites.

## Diagnosis path

1. Find who consumes the stub's outputs: content-search the attribute names
   (`bundle\.bests|bundle\.ohlc|bundle\.tas`, class name, etc.) across `python/`.
2. Read the consumer's row-access semantics. `row.get(col)` followed by a
   `continue`/skip is the silent-drop signature — column renames become empty
   result sets, never KeyErrors.
3. Settle WHICH side drifted via git archaeology (do not guess):
   - `git log --all --oneline --follow --diff-filter=A -- '*markettas*'`
   - Read the ORIGINAL upstream module: `git show <sha>:notebooks/markettas/datasource.py`.
     Its `normalize_bests()` enforced required columns
     `["Time","Bid Volume","Bid Price","Ask Price","Ask Volume"]` + derived
     `timestamp`. Verdict: the Andromeda stub drifted away from the upstream
     contract; fix the stub, never bend the consumer toward the broken shape.
4. Check no third party depends on the WRONG shape before fixing
   (search for the old column names in consuming position).

## Fix + regression rule

- Align the stub to the upstream contract (two-sided quotes here: the provider
  keeps only rows where BOTH bid and ask prices are non-null — single-sided
  quotes are dropped by design).
- Add a regression test that drives the STUB THROUGH THE REAL CONSUMER:
  `MarketTaSDataSource → CmeBookProvider.fetch(start, end, pair=...)` → assert
  non-empty snapshots, two-sided top-of-book, `bids[0] < asks[0]`, plus an
  exact-column-set assertion on the frame. A stub-only unit test cannot catch
  this class.
- If the stub has no test file of its own, that is itself the smell — create one.

## Generalization

Before changing ANY stub/fixture/frame shape (columns, attrs, keys), grep the
production consumers' access patterns first. Prefer adding a consumer-through
test whenever a stub feeds production code. When hunting across a tree, treat
stubs as nodes in the relation graph (upstream/downstream questions apply),
not as inert test helpers.
