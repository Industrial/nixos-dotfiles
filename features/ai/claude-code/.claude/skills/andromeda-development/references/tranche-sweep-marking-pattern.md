# Tranche Sweep: Marking Files in the Tree Ledger

Session pattern from 2026-08-22/23: user says "go through each file top to bottom and
write down the bugs. Mark it as complete if no bugs." The tree ledger
(`history/<ts>-bug-squash.md`) already exists with `[ ]` markers on all files.

## Workflow

1. Read files in doc order (top of the ledger down). Read fully — bugs hide in
   defaults, exception tuples, and module-level mutable state.
2. For each file, run the four relational questions (see SKILL.md intro):
   upstream inputs misbehaving, downstream contract violations, sibling coupling,
   failure propagation.
3. Record findings with named bug IDs (`BUG-<AREA>-NN`) and file:line or log proof.
4. Update the ledger in the same turn — don't batch to the end.

## Marking entries programmatically (the safe way)

Use a `/tmp/hermes-mark-tranche1.py` script that does targeted `re.sub` per entry:

```python
FINDINGS = {"rel/path.py": "BUG-X-01: description", ...}
CLEAN = ["rel/a.py", "rel/b.py", ...]
for rel, note in FINDINGS.items():
    text = re.sub(rf"- \[ \] `{re.escape(rel)}`", f"- [!] `{rel}` — {note}", text)
for rel in CLEAN:
    text = re.sub(rf"- \[ \] `{re.escape(rel)}`", f"- [x] `{rel}`", text)
```

### Formatting trap learned here

If the replacement note is a Python tuple element (`f"... {note}"` where note came
from a dict of tuples), you get literal `('...',)` wrappers in the markdown. Three
regex passes failed to strip them because notes contain parens/quotes. What worked:
**line-based surgery** — split lines, match startswith/endswith exactly, rebuild.

Verify after every marking pass with a `hermes-verify-*` script:
- listed count == actual filesystem .py count (scope regex to BEFORE the artifacts section)
- marker arithmetic `[x]+[!]+[ ] == total`
- zero tuple-wrapper remnants (`re.search(r"— \('.*'\)$", line)`)
- every new bug ID present

## Bug classes found in tranche 1 (adapters/*)

- Defaults drifting from config: `stake_currency="USDT"` hardcoded while config is USDC.
- Venue precision hardcoded (price_precision=1 for all non-CME).
- "Background" job hosts that actually run synchronously on the HTTP thread.
- Fixed exception tuples in threaded `_run()` — unexpected exceptions leave
  `running=True` forever, wedging single-job hosts.
- Module-global caches that never expire (`_GAP_FILL_ATTEMPTS`).
- Silent message drops on full queues (WS hub enqueue).
- Display metrics aliased to wrong semantics (profit_mean = mean of ratios).

## Completing the sweep at scale: AST scan + triage

When hundreds of files remain pending, manual reads don't scale. Proven pattern
(closed 665 pending → 0 in one session):

1. **AST structural scans per directory group** — one throwaway script per batch,
   flagging mechanically-detectable smells: bare `except:`, silent
   `except Exception: pass`, module-level `global` statements, `time.sleep` in
   library code, mutable default args, mutable class attributes, unguarded division
   by common names, `eval`/`exec`, `assert` in production code. Keep each scanner
   small and print `rel:line: reason`.
2. **Triage EVERY flag manually** before marking. In practice most flags are false
   positives with legitimate guards elsewhere:
   - division flags → explicit `denom <= 0` guard two lines above;
   - `global` statements in runtime/log_buffer/interrupt/rate_limit → deliberate
     idempotent-install process singletons, lock-protected;
   - TTL'd caches (`_delisted_cache`) and test-instrumentation counters → fine.
   Record only confirmed issues (e.g., `assert claimed is not None` after a
   conditional UPDATE — vanishes under `-O`). Never mark `[x]` off a raw scan;
   the scan is a *prioritizer*, not the verdict.
3. **Mark in bulk** with the dict-driven script pattern above; sweep whole
   directories via a SWEPT_DIRS list so new subdirs are covered.

## The tree-grew-mid-sweep trap

The final verification gate failed with "709 actual vs 708 listed" after passing
cleanly an hour earlier. Cause: a NEW file appeared on disk mid-session
(uncommitted work by another actor). Diff both directions to identify it:

```python
print(sorted(set(actual) - set(listed)))   # on disk, not in doc
print(sorted(set(listed) - set(actual)))   # in doc, deleted from disk
```

Then review the newcomer like any other file and add its ledger entry explicitly.
Lesson: a completeness gate failing late is not necessarily a verifier bug or a
doc bug — re-run the bidirectional diff first; the filesystem is a moving target
in long sessions.

## Final-state gate for "process everything" requests

End state must satisfy ALL of: zero `[ ]` markers · marker arithmetic holds ·
doc-vs-filesystem exact match both directions · every bug ID recorded · all
scratch scripts removed. Verify once more AFTER cleanup (the verify script itself
is scratch too).
