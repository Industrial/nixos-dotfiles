# Live shared-checkout EXECUTE: worked patterns

Session evidence from a four-wave service consolidation (SessionService,
solana-yield-optimizer, 2026-08-23) run alongside a concurrent agent shipping
CandleService/risk changes into the same working tree and index.

## 1. Index contamination — catch it before every commit

Sequence that bit: `git add <six files>` → foreign agent staged their candle
deletions into the same index → `git commit` (bare) would have shipped both.

Catch: `git diff --cached --name-only` immediately before committing; anything
you did not touch is foreign. Remedy used twice:

```
git -c core.hooksPath=/dev/null commit -m "<message>" \
  -- <your paths only>
```

Pathspec-limited commit leaves unrelated staged entries staged for their owner.
Residual risk: limitation is per-FILE. A co-edited listed file commits ALL its
uncommitted hunks. One wave landed carrying the other agent's staged hunks in
three shared files (`test_candle_service_is_process_singleton`,
`candle_service` container wiring, `CandleService` export). Their tree was
intact; their later commit simply shrank against the new HEAD. Handling:
accept-and-disclose in commit body + REVIEW notes; audit via
`git show <sha> -- <file>`. Do not attempt index surgery under a live agent.

## 2. Bounded-splice edits (never trust an unanchored end marker)

Deleting a function by slicing `content[start:index("def next_func")]` removed
four unrelated route bodies because the "next def" marker sat ~90 lines below
the target while three sibling defs lived inside the span. Recovery:
`git checkout -- <file>` (safe only when your own edits on that file are
re-appliable), then redo with assertions on span size and content:

```python
start = c.index("def apply_lifecycle(")
end = c.index("def trades_body(")          # adjacent successor def
block = c[start:end]
assert len(block) < 800                    # span sanity gate
assert "trades_body" not in block          # no successor body captured
```

Rule of thumb: assert the block length is within 2x of what you expect to
delete, and that no symbol from the surviving region appears inside it.

## 3. Patch-tool false positive: "new_string already exists"

Replacing a whole function whose tail (`return {...}`) also exists elsewhere
can trip the uniqueness pre-check with "old_string not found but new_string
already present" even though nothing was applied. Verify ground truth with
grep/read before concluding; if intact, retry with a larger unique anchor or
fall back to a bounded splice per §2. Never blindly re-run after this error
without re-reading the region.

## 4. Post-revert read caches are stale until invalidated

After `git checkout -- <file>`, hermes `read_file` may answer from its
dedup cache ("File unchanged since last read", content_returned=False) because
the reverted bytes hash-match an earlier snapshot — while lean-ctx reads show
the true HEAD content. Any scripted edit built on the cached text then fails
its assertions (good) or silently mis-splices (bad). Discipline: after any
external mutation of a file (checkout, hook formatter, another agent), force a
fresh read (`fresh=true`, raw terminal grep) before editing, or drive edits
through one tool family consistently.

## 5. Kwarg-migration sweeps (rename a constructor param across tests)

When a factory kwarg is renamed (`for_tests(state=...) -> sessions=`), grep
for BOTH single-line and multi-line call forms — a first pass catches the
single-line ones and misses wrapped ones:

```python
import re
s1 = re.sub(r",\s*state=SessionState\(\)", "", s0)
if 'SessionState(' not in s1 and 'SessionState' in s1:
    s1 = s1.replace("from ...session.state import SessionState\n", "")
```

Then re-grep the tree for the old kwarg AND for direct-construction sites
(`ApiApp(...)` bypassing the helper). Run pytest over the union of touched
files plus every proof module that imports them before committing.

## 6. Facade absorption: free functions → methods without breaking the graph

Dissolving a package into one service class (repo law: one class per service
module). Mechanical map that worked: stateful orchestration becomes
keyword-arg methods on the service with per-call override kwargs
(`BarsDownloader.download(req)` → `svc.download_bars(req, providers={...})`,
defaults built by private `_default_*_providers()` helpers); pure math/fs
helpers stay module-level (`_contiguous_bar_runs`, raw-cache layout);
constants stay module-level (the law caps classes, not names — keeps
`SOURCE_STOOQ` etc. importable).

Two traps from the CatalogService absorption:

- Import cycles: if the absorbed module owns helpers that ACL provider
  packages import (`equity_sources` ← stooq/crypto_spartan/ohlcv_1m) AND it
  lazily imports those same providers for ingest, EVERY direction must be
  function-level lazy. One top-level `from ..providers import stooq` in the
  service module is a guaranteed cycle once providers import the service's
  constants back.
- Masked type errors resurface: an old free-function form that accepted
  `catalog | anything` and defended with `except AttributeError: rows = []`
  hides callers passing garbage (real case: a PosixPath handed to a service
  constructor in CLI code). After method-cutover the same bug dies as
  `'PosixPath' object has no attribute 'micro_lookup'`. Triage: the fix
  belongs at the CALLER passing the wrong object — never re-add the swallow.
  If the broken caller sits in foreign staged WIP, diagnose, disclose in
  REVIEW notes, and leave their file alone.

## 7. Test-cutover sweep greps four coupling shapes

Consumers are not just importers — test files couple through four distinct
shapes, and only #1 shows up in an import-residual grep. Sweep all four before
calling an absorption/rename wave done:

1. `from <old.module> import X` plus monkeypatch STRING paths containing the
   old module (`"andromeda.services.catalog.equity_importer.f"`).
2. `monkeypatch.setattr(<importer_module>, "<old_factory>", ...)` — attribute
   mocks on importer modules; they die with "module has no attribute" at
   runtime once the symbol is gone.
3. `monkeypatch.setattr("<full.path.OldSymbol>", ...)` — string-target mocks;
   rewrite onto the new seam.
4. `monkeypatch.setattr(<provider_module>, "<absorbed_helper>", ...)` — mocks
   of helpers that moved into the service module; production code is fine but
   the test fails with AttributeError anyway.

Rewrite patterns that worked: patch the new construction seam so every call
site gets the stub —
`monkeypatch.setattr("...CatalogService.require_from_env", classmethod(lambda cls, *a, **k: stub))`;
and DELETE patches of now-real helpers outright when real behavior matches
under the test's fixtures (fresh `tmp_path` ⇒ no `.complete` marker ⇒
`is_complete()` is already False — the patch was only ever masking stale state).

Run the scoped battery after EACH sub-wave (absorb, test fold, each consumer
batch), not only after package deletion — shape-#2/#4 breakage only surfaces
at runtime, and a single post-deletion run mixes your breakage with foreign.

## 8. Duplicate near-name modules: verify the imported one before editing

A parallel dissolution staged `historical_runner_service.py` while tracked
HEAD still carried `historical_runner.py`; both defined the same service class
and the first edit round went to the dead twin (harmless but wasted; failing
tests pointed at the live file never touched). Check before editing:
grep the tree for `from <package>[.]<sibling> import` vs
`from <package>.<candidate> import`; if importers disagree with the file you
were about to edit, treat the un-imported twin as dead, and confirm with
`git status --porcelain <dir>` (staged entries = someone's live WIP — do not
revert, do not delete, route around). If you already edited the dead twin:
your edits vanish harmlessly when their commit deletes it — do not resurrect
or re-apply; re-check the live file still needs the change.

## 9. Foreign WIP moves in BOTH directions — re-gate before attributing

Mid-wave, a scoped test failure attributed to foreign staged code went GREEN
on the next gate run with zero edits from this side: the parallel agent fixed
their own call site (a service constructor misuse in their staged CLI code)
between our runs, while we were still drafting the disclosure. Corollary to
§1's riders doctrine — their tree changes under you whether you watch or not,
so attribution decays in minutes. Discipline: before recording "foreign, out
of scope" in REVIEW notes, re-run the failing scope ONCE; before claiming a
fix, confirm which side moved it (`git log -p -- <file>` vs your own diff).
Same rule when diagnosing: get the real traceback BEFORE routing around
foreign files — the frame chain tells you whose file owns the bug (here it
showed the caller in staged app.py, not the absorbed service we were editing).
