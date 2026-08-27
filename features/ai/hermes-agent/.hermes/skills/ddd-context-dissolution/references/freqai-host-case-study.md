# freqai_host dissolution — FULLY EXECUTED (2026-08-23)

~7,400 lines across 39 modules — an order of magnitude bigger than any
dissolved context so far. ALL WAVES LANDED: bd43e456 (main dissolution, 113
files), 90e1f828 (gates + ARCHITECTURE row), 0a920ac9 (tree-removal companion
completing the tombstone), 7b6c8c26 (stale-buffer repair of 4 shared files).
Executed by an orchestrator + three parallel leaf subagents for Wave A;
Waves B/C ran as scripted parent-side phases after the subagents all hit the
600s timeout. Catalog + execution sessions were dissolving concurrently —
their commits landed mid-flight and interacted with this work in ways worth
studying before any future shared-worktree campaign.

## Final home map (what landed where)

### 1. Pure domain math → `domain/`  ✅ COMMITTED (bd43e456)
config.py→freqai_config.py (fixed the run_config.py:8 domain→contexts purity
violation en route); features/targets/outliers/corr_mtf/event_time/parity/
expand → freqai_*.py; tensor.py→l2_tensor.py; tensor_model.py→
tensor_stub_model.py. Tests moved alongside; colocated-test SPLIT per class
home did not apply here (one class per module already).

### 2. Vendor machinery → `adapters/driven/acl/`  ✅ COMMITTED
lopezdeprado subtree → acl/lopezdeprado/ (Wave A2 subagent, clean);
models.py+data_provider.py+hyperopt/ → acl/freqtrade/…; adapter_start.py →
acl/nautilus/freqai_start.py (RENAMED at move — patch-target strings in
tests updated to match); artifacts/* → acl/nautilus/artifacts/. legacy_pickle.
_CANON remap table extended: legacy artifact GLOBAL paths
(andromeda.freqai_host.host / andromeda.contexts.freqai_host.host) now remap
to andromeda.services.freqai_host — old pickles keep loading.

### 3. Orchestration → `services/freqai_*.py`  ✅ COMMITTED
host.py→freqai_host.py (FreqAIHost name stable §3.6); pipeline, lifecycle,
retrain, adaptive, walkforward, sequence, operator each one flat file.
RetrainSchedule stayed with freqai_retrain (not domain) — no pressure to move.
expand_all invocation folded into freqai_pipeline as planned.

### 4. Shells/residue  ✅ EXECUTED
application/ports/* deleted shell; trace.py rewired-to-afml then deleted;
leakage_acceptance extracted into a real module (test + proof repointed) —
later RELOCATED again to test/proofs/ beside its importer when the tombstone
demanded full context evacuation; walkforward_proof.py + its test → test/proofs/.

## Wave-by-wave execution evidence

Wave A (3 parallel subagents): A1 timed out AFTER landing all moves; A2 same;
A3 died early with partial work — orchestrator absorbed A3 manually and fixed
A1/A2 stragglers. Lesson recorded in SKILL.md Techniques (subagent-timeout,
straggler classes).

Wave B phase 1 (7 service files): git mv host/pipeline/lifecycle/retrain/
adaptive/walkforward/sequence + tests; scripted whole-line import rewrite over
python/**/*.py EXCLUDING contexts/freqai_host/** (skip-list needed so the
rewrite doesn't fight files still being evacuated); 33 consumer files rewired
incl. both function-local imports in cli/app.py. Intra-context stragglers:
artifacts_test/store_test/materialize(.py/_test) still referenced old service
paths; store_test's rewrite_legacy_module assertions updated to expect the new
canonical mapping. One `from andromeda.contexts.freqai_host import walkforward
as wf` package-import form missed by path-based rules — caught by pytest, fixed
to `from andromeda.services import freqai_walkforward as wf`.

Wave B phase 2 (vendor ACLs): models/data_provider moves; models_test had a
package-form import of `models as mod` — same fix pattern.

Wave B phase 3 (hyperopt/adapter_start/artifacts): adapter_start RENAMED to
freqai_start at move; monkeypatch string targets inside its test rewritten to
the new module path; one E501 from a lengthened patch string (wrap args).
memory_store.py `_QUESTDB_STORE_PATCH_TARGETS` tuple is a STRING-literal
consumer inventory — must be rewritten like imports (see SKILL.md string-
literal lesson).

## Commit dance under concurrent sessions (the hard part)

- bd43e456: mixed shared files (cli/app.py, app_main_test.py, makers.py,
  run_config.py) sanitized via backup → HEAD-version + only-my-substitutions →
  pathspec commit → restore originals. Two gotchas hit live:
  (a) an aborted first attempt (bad pathspec token) left the RESTORE already
  executed, so the retry committed FOREIGN worktree content — swept hunks in
  makers.py referenced services/execution/, a package the other session hadn't
  landed yet. Detected immediately via `git show HEAD:<file> | grep`; NOT
  amended (foreign commits were landing on top) — recorded as known blemish.
  (b) The blemish self-healed when the execution session landed their wave
  tracking that package. Never publish a foreign half-done package yourself.
- Pathspec truncation risk: very long commit commands get mangled (one attempt
  silently dropped trailing paths). After every commit, diff
  `git show --stat HEAD` against your expected file set; land missed endpoints
  in an explicit companion commit (0a920ac9 exists solely because the tombstone
  commit's pathspec omitted the renamed operator/leakage files — without it the
  tombstone would be false on pristine checkout).
- 90e1f828 landed gates/docs BEFORE 0a920ac9 landed the tree removal — order
  was forced by the truncated-pathspec recovery, not preference. Preferred
  order remains: tree moves first, gates last.
- 7b6c8c26 repair-forward: catalog w2 wrote stale editor buffers over FOUR
  shared files, resurrecting dissolved contexts.freqai_host imports and breaking
  collection tree-wide. Sanitized per-file commits (HEAD + only my substitutions)
  restored canonical imports; their pending deltas re-restored after. See
  SKILL.md sanitize-dance-v2.

## Verification evidence

Post-commit battery on HEAD: 28 relocated test targets + layout gates green;
ruff F821 clean on all moved trees; leftover grep shows only the two INTENTIONAL
legacy-pickle remap literals. Three ft_17_58 failures in shared-worktree runs
attributed via pristine `/tmp/head-proof` worktree (green there = foreign WIP):
first the bare `QUESTDB_PG_URL=unused://` DSN artifact, later the catalog
session's half-landed CatalogService cutover eagerly dialing QuestDB. Re-run
scoped suites after each foreign wave lands to confirm.

## Deferred-to-owner items (all since healed or owned elsewhere)

- MicrostructureService re-export sat uncommitted in services/__init__.py until
  adccd252 (parallel rename became HEAD; also finished ForwardRunnerService→
  RunnerService there and deduped a double __all__ entry).
- freqai_start logger name followed the module move (small follow-up commit).
- freqai_operator.py CatalogService cutover belongs to the catalog session —
  never commit another session's seam migration mid-flight.

## Status: COMPLETE — supersede this file's plan sections on future reads

All waves landed and verified (see SKILL.md Techniques for the distilled
lessons: subagent-timeout absorption, straggler classes, sanitize-dance v2,
truncated-pathspec companion commits). Keep this file as the worked example
of dissolving the LARGEST context under two concurrent foreign sessions.

## Character split (three kinds + residue)

### 1. Pure domain math (~900 lines, vendor-free) → `domain/`  ✅ EXECUTED
| Source | Destination | Notes |
|---|---|---|
| config.py (`FreqAIConfig`) | `domain/freqai_config.py` | ✅ moved; fixed the live domain→contexts purity violation in run_config.py:8 |
| features.py (% column selection) | `domain/freqai_features.py` | ✅ |
| targets.py (&- labels) | `domain/freqai_targets.py` | ✅ |
| outliers.py (DI z-scores) | `domain/freqai_outliers.py` | ✅ |
| corr_mtf.py (asof merges) | `domain/freqai_corr_mtf.py` | ✅ |
| event_time.py (causality asserts) | `domain/freqai_event_time.py` | ✅ |
| parity.py (MAE) | `domain/freqai_parity.py` | ✅ |
| tensor.py (`build_l2_tensor`) | `domain/l2_tensor.py` | ✅ sibling of L1/L2 snapshots moved in 3ce8bb66 |
| tensor_model.py (`TensorStubModel`) | `domain/tensor_stub_model.py` | ✅ |
| host.py `StubModel` dataclass | `domain/freqai_stub_model.py` | NOT YET MOVED — Wave B with host service |
| expand.py grid half | `domain/freqai_expand.py` | ✅ (invocation half still folds into pipeline service, Wave B) |

### 2. Vendor-coupled machinery → `adapters/driven/acl/`
| Source | Destination | State |
|---|---|---|
| adapters/lopezdeprado/{bridge,lopezdeprado_backtest,lopezdeprado_ft_result} | `acl/lopezdeprado/` | ✅ EXECUTED (subtree git-mv; zero deps on pure-math modules pre-checked) |
| models.py + hyperopt/ + data_provider.py | `acl/freqtrade/…` | Wave B |
| adapter_start.py | `acl/nautilus/adapter_start.py` | Wave B |
| adapters/artifacts/* | `acl/nautilus/artifacts/` | Wave B; CONFIRM NT-coupling by import audit first |

### 3. Orchestration → `services/`  (Wave B)
host.py `FreqAIHost` → services/freqai_host.py (central contract, name stable
§3.6); pipeline→freqai_pipeline (absorbs expand_all invocation); lifecycle,
retrain (RetrainSchedule dataclass → domain), adaptive, walkforward (536L
joblib grid) each one flat job-service file. sequence.py = fold candidate into
freqai_pipeline or own file at execution. Six small services around the host
contract; NO package hierarchy absent explicit user order (Q1).

### 4. Shells/residue  ✅ EXECUTED
- application/ports/* ×3 Any-typed Protocols — deleted, zero consumers.
- trace.py — was NOT a pure shell: two live importers (adapter_start.py,
  lifecycle.py) rewired to import afml.logging_util directly, THEN deleted.
- leakage_acceptance_test.py was IMPORTED BY ft_17_78 proof — extracted real
  module freqai_host/leakage_acceptance.py first, test + proof repointed.
- walkforward_proof.py → relocated to test/proofs/ (runnable script, Q4 rec).
- ports_test.py / trace_test.py died with their subjects.

## Consumer pressure (~64 external sites)

Heaviest magnets: cli/app.py (artifacts.materialize/.store, hyperopt.engine,
lopezdeprado.*, operator, walkforward — incl. FUNCTION-LOCAL imports at :643
and :717 that a top-of-file-only sweep misses), http/backtest_rpc.py +
backtest_persist.py, http/app.py (:55), composition/factories/makers.py (:20
+:50 function-local attach_freqai_start — SHARED MAGNET), execution/adapters/
nautilus/{nt_backtest,nt_compose}.py, strategies/{freqai_ml,freqai_afml}_test.py,
strategies/lopezdeprado.py (bridge.label_ohlc), ~20 test/proofs files.

## Wave A execution evidence + lessons

- Three parallel leaf subagents, disjoint ownership: A1 pure-math→domain,
  A2 lopezdeprado subtree, A3 shells/helpers/script relocation. Pre-flight
  intra-context import grep proved boundaries before splitting (lopezdeprado
  imported nothing being moved by A1/A3).
- A1 hit the 600s leaf timeout AFTER all moves landed — timeout kills
  reporting, not necessarily work: INSPECT THE TREE FIRST, finish residual
  stragglers yourself instead of re-dispatching.
- Straggler classes the scripted old-path grep MISSED (all caught only by
  running relocated tests): 4 function-local imports; 1
  importlib.import_module("<path>") STRING literal; 2 rewrite rules that
  emitted UNPREFIXED new names (andromeda.domain.parity instead of
  andromeda.domain.freqai_parity). Post-sweep greps must cover function-body
  imports and string literals, and spot-check that rewritten targets actually
  exist under their NEW names.
- Verification after A1+orchestrator fixes: full scoped suite exit=0
  (52 passed incl. seven ft_17_6x/7x proofs); straggler-path re-verification
  green post-commit-review.

## Open decision points (user answered 2026-08-23: "Execute all waves")

Q1 shape: six flat job-services (rec, user approved execution) — no hierarchy
absent explicit order. Q2 name: FreqAIHost keeps FT-term-of-art name (§3.6);
flag to user if they want the no-acronyms ruling applied here. Q4 executed per
recommendation (relocated, not deleted). Q3 resolved as "immediate" for Wave A;
Wave B timing still coordinates with catalog/execution sessions on makers.py.

## Wave C (GATED on catalog landing)

operator.py imports contexts.catalog.application.catalog_factory/catalog_loader.
Re-audit AFTER catalog session's rewrite lands; then tombstone test in
ddd_layout_import_rules_test.py, _DISSOLVED_DOMAIN_FILES += ten new domain
files, ARCHITECTURE.md services-table row (draft: FreqAIHost registry/train/
predict; hook-order pipeline; live retrain; adaptive + walkforward grids; FT
model ACL; artifacts stores), leftover grep empty, ruff F821 tree-wide.
