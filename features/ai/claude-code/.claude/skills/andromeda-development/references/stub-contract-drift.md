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

## Instance #2 (2026-08-24): the stub IS the production source — inverted drift

The 2026-08-23 column-drift was fixed in fixture shape only; the deeper problem
surfaced the next day from the OPERATOR side. `MarketTaSDataSource` is not a
test double that happens to sit in `adapters/driven/acl/providers/` — it is THE
production data source for all three CME providers, and it is entirely fake:

- `list_sessions()` → hardcoded `[date(2025, 9, 2)]`, `data_root` ignored.
- `load_session()` → fabricates a 1440-row dummy frame (`close = 100 + i*0.5`)
  + synthetic bests/tas; `FileNotFoundError` otherwise — swallowed by every
  caller's `except FileNotFoundError: continue`.

So the ~200 real `notebooks/data/MarketTaSData_*` day folders are never read;
operator `import download` "succeeds" with zero/tiny `n_rows` because the single
fabricated day is dedup'd against existing QuestDB timestamps
(`CatalogService._existing_bar_ts`). Tests stay green precisely BECAUSE fixtures
pin the same magic date/symbols as the stub — the suite encodes the fantasy as a
contract (instruments_test expects `[MES/USD, MNQ/USD]`).

Inverted lesson vs instance #1: there the STUB drifted from the real contract and
the fix aligned it to upstream. Here the stub replaced a deleted REAL module
(`notebooks/markettas/datasource.py`, removed in 1b387fa8 "remove aurora and
markettas modules to simplify test suite") and the fix is porting the real
filesystem loader back under the same `list_sessions/list_symbols/load_session`
surface. Audit question that catches both: **does any test construct REAL input
files on disk AND drive them through the real (unpatched) loader?** If no test
ever touches the filesystem reality, a fabricated-source stub can ship as
"production" for weeks. Full chain: `references/cme-markettas-ingest-and-cli.md`.
