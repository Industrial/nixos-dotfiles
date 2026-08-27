# Case study: package → single Service consolidation (services/freqai/* → FreqaiService)

Worked example 2026-08-24: eight modules (one host service + seven free-function
job modules) merged into ONE `services/freqai_service.py` per explicit user
rulings. Plan artifact: `.cursor/plans/freqai-service-consolidation.plan.md`.

## Ruling-driven extraction set (before building the merged file)

One-class-per-service-module law forces out everything that is not the service:

| Candidate | Destination | Rule |
|---|---|---|
| State+behavior dataclasses over their own fields (RetrainSchedule) | `domain/<name>.py` | placement table |
| Result carriers (TrainPredictResult, WalkforwardResult, AdaptiveBacktestResult) | `domain/`, pure fn companions (prediction_columns) travel along | one type per file |
| Vendor-handle types (StubModel) | `domain/` per user ruling; strip acl-typed annotations — dispatch structurally (`getattr(backend, "predict_proba", None)`) to preserve domain purity | §2 |
| Vendor-interface shims ("IFreqaiModel-shaped") | domain or acl per ruling (SequenceModelAdapter → domain here) | |

Register every new domain file in the ddd_layout dissolved-domain purity gate
list in the same wave.

## Assembly by verbatim segment splicing

Build the merged module programmatically: extract each function/class body
verbatim between exact anchors, then apply per-segment transforms. Never retype
bodies — fidelity beats elegance and diffs stay reviewable.

Pitfalls hit, all reproducible classes:

- **Indentation trap**: substring replace anchors break after `indent()` —
  leading spaces differ. Use indentation-agnostic `.replace()` on the distinctive
  middle of a line, or line-index surgery (`splitlines` + anchor-by-content).
  Three separate script crashes were all this one bug.
- **Idempotency is mandatory**: shared-worktree reruns happen. A non-idempotent
  kwarg insertion ran once per rerun and stacked 8 duplicate parameter lines —
  caught only as `SyntaxError: duplicate argument`. Every transform must check
  final state (`if new not in t`) before applying.
- **Insert-after-last-andromeda-import** can land INSIDE a parenthesized import
  block → SyntaxError at next parse. Parse after every file write.
- **Ruling "no module-level private functions"**: internals become underscore
  *methods* (static for pure math, instance for state). Joblib `delayed()`
  needs a pickleable top-level-or-static callable — converting the segment fn
  to a `@staticmethod` preserves qualname pickle semantics exactly.
- **Instance-state fold**: LiveRetrainHost folded into ctor state
  (`schedule`/`feature_parameters`/`label_col` fields) while verbs gained
  explicit override kwargs (`schedule=...`) so old call shapes still work;
  adaptive backtest additionally gained the `config=` kwarg it always took as
  free-function parameter.

## Post-assembly audits (all cheap, all caught real bugs)

1. AST walk: module-level `FunctionDef` count must be ZERO (ruling check).
2. Regex sweep for unqualified helper calls: any `_bars_to_frame(`/`_wt(`
   etc. without `self.`/`Cls.` prefix = missed self-threading.
3. One live import + ctor + trivial static-call probe under the project venv
   BEFORE batteries — missing header imports (`summarize_side`,
   `run_feature_engineering_expand_all`) surface only as runtime NameError.
4. Stale-token grep inside the new file (old class name, folded wrapper name).

## Import cycles: the deferred import was load-bearing

Absorbing adapter-called helpers makes `service → materialize.py → service`:
moving `run_feature_engineering_pipeline` to module level in the consumer broke
it. The pre-existing function-local import existed precisely to prevent this —
keep it deferred at the call site with a comment naming the cycle edge.
Signature: `ImportError: cannot import name 'X' from partially initialized
module` names the exact edge. Corollary: don't "clean up" function-local
imports during moves without checking who imports the module.

## Test consolidation

- Merge substantive suites under section banner comments; L0 smokes die.
- Module alias `wf = FreqaiService` keeps `wf._private_helper` tests working.
- Fixture-name collisions across merged sections (`_cfg` defined twice): the
  later definition silently wins and earlier-section tests fail with confusing
  kwarg TypeErrors — rename per section (`_op_cfg`).
- Monkeypatch targets move from the old class-module to the NEW module object
  (`import ... as wfm`; `setattr(wfm, "Parallel", ...)`): patching the class
  attribute misses call sites reading module globals.
- Prepending an import above `from __future__` → SyntaxError; insert after the
  future/import block instead.
- Watch for hybrid double-receiver artifacts from scripted rewrites
  (`FreqaiService().run_train_predict(\n host,`).

## Pickle remap retarget

`legacy_pickle._CANON` maps legacy GLOBAL paths to the CLASS's defining module —
after extracting StubModel to domain, the remap target becomes
`andromeda.domain.stub_model`, NOT the service module. Unpickling resolves by
module+qualname; pointing at the service would break artifact loading even
though the import works fine everywhere else.
