# Verify-The-Verifier: completeness/equality gates

Pattern for any task where you assert "X is complete" or "A matches B" —
config rewrites, tree inventories, migration checklists, doc-vs-filesystem sweeps.
The gate itself is code, and code has bugs. Verify the verifier.

## The pattern

1. Write the assertion script under `/tmp/hermes-verify-<topic>.py` (OS-safe temp
   path, `hermes-verify-` prefix so it's recognizable and cleanable).
2. Make checks bidirectional and arithmetic-closed:
   - set(A) == set(B) — one-directional subset checks pass while orphans remain
     (live find: instruments map kept ENS/MARK keys that were in no pairlist).
   - counts must CLOSE: `[x]+[!]+[ ] == total`. If the parts don't sum to the
     whole, something was double-counted or missed.
3. Run it against the artifact; on failure, diff BOTH directions before touching
   the artifact:
   - `in A not in B` AND `in B not in A`
   - The defect may be in the verifier (over-broad regex), not the data.

## Real failure: the over-scoped regex

Tree-doc verification reported 711 listed entries vs 708 actual files. Diffing
both directions showed zero missing files and exactly 3 phantom entries — all
from a trailing "non-python artifacts" section (config JSON, schema.sql, compose
glob) matched by the same line-regex as py-file entries.

Fix: scope the extraction regex to its section
(`text.split("### config & deployment artifacts")[0]`), never run completeness
regexes over a whole mixed-content document.

## Script hygiene

- Name with `hermes-verify-` prefix; keep checks as `(bool, message)` tuples so
  failures print all at once instead of stopping at the first.
- Print per-check OK/FAIL lines plus a final `ALL CHECKS PASSED (n/n)` and exit 1
  on failure — output is the evidence for ad-hoc verification claims.
- Delete the script after running (`rm -f /tmp/hermes-verify-*.py`). It's a gate,
  not a fixture; durable assertions belong in `*_test.py`.

## When this applies

Any "prove X" turn where no canonical suite covers the artifact: config JSON
content, generated docs, inventory ledgers, migration reports. State plainly in
the reply that this is ad-hoc script verification, NOT suite green — and note the
canonical suite state separately if it exists.
