# Serializer Semantics Drift — BUG-SER-02 case (2026-08-23)

## What happened

Commit f5f626d1 rewrote `adapters/driven/acl/freqtrade/serialize.py::trade_to_ft_dict`
to correct FT base-size semantics: `"amount"` became `(stake × leverage) / open_rate`
(base-asset quantity), no longer the stake itself. Its own unit tests
(`serialize_test.py`: `amount == 0.25` for stake 25 @ open_rate 100) were updated — green.

Four DOWNSTREAM consumers still encoded the old `amount == stake` contract and went red:

1. `domain/accounting.py::assert_fill_matches_trade` — raised TradeBookError
   "FT amount must equal stake" on EVERY entry fill → `apply_entry_fill` /
   `apply_exit_fill` wedged. Production path, not just tests.
2. `adapters/driven/acl/freqtrade/trade_proxy.py::TradeProxy.amount` — the
   strategy-facing callback surface returned stake instead of position size.
3. `test/proofs/ft_17_48_trade_entity_fields_test.py` — `ft["amount"] == 210.0`.
4. `test/proofs/ft_17_76_proof_ft_nt_fill_accounting_test.py`
   (+ ft_17_80 which aggregates it).

## Symptom → diagnosis path

- Tree-ledger sweep ran the proofs suite FIRST → 7 failures in one shot, all
  funneling through `assert_fill_matches_trade`.
- The error string "FT amount must equal stake" located the stale invariant instantly.
- Git archaeology settled WHICH side drifted:
  `git show f5f626d1^:python/andromeda/adapters/driven/acl/freqtrade/serialize.py`
  showed the pre-commit version returned `stake.amount`; commit message said
  "enhance trade serialization"; serialize_test asserted the NEW semantics →
  serializer was canonical, consumers were stale. Never revert the side whose
  tests encode intent.

## Fixes applied

- Accounting invariant now proves fill→FT projection sync with a DERIVABLE identity:
  `float(ft["amount"]) == fill.qty * fill.price / trade.open_rate`
  (qty×price reproduces base size exactly at leverage=1).
- `TradeProxy.amount` → `stake.amount / open_rate` (docstring: FT base size).
- Proof asserts updated to derived values: `ft["amount"] == entry_fill.qty`,
  `proxy.amount == stake/open_rate`, `ft["amount"] == 2.1`;
  accounting_test monkeypatch lambda divides by open_rate too.

## Class-level rules

- High-fan-out converters/serializers: changing a field's MEANING invalidates every
  consumer's encoded assumption (invariant asserts, duck-typed proxies, proof tests)
  — the converter's own tests passing proves nothing downstream. Before merging,
  grep consumers for literal assertions on the changed key:
  `grep -rn '"amount"' python/andromeda --include='*.py'`.
- Cross-layer contract checks should assert DERIVABLE identities
  (qty×price/open_rate), never frozen literals carried over from the old shape.
- In any sweep, run proof/contract suites before reading code — cross-file drift
  surfaces as red tests in seconds; manual tracing takes hours.
- Lint triage discipline held here: I001 import-sort findings in touched files were
  first verified pre-existing (`git stash -q && ruff check ... && git stash pop -q`),
  then auto-fixed anyway because the files sat inside the fix's blast radius.

## Verification

Scoped suite after fix: proofs + accounting_test + acl/freqtrade tests →
247 passed, 5 skipped; ruff clean on all six touched files.
Full-tree regression (`pytest python/andromeda`) launched at session end —
check its result before committing.
