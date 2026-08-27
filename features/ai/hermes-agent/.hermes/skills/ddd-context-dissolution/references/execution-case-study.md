# Execution-area dissolution — EXECUTED 2026-08-24 (commit 84490a41)

Mission pln-mt69l5t6-drxwm4 Phase A · companion mission pln-mt6z4kln-vdh78c
(phase-a1-dissolution-moves tsk-mt6z4kmu-38bxbv, phase-a2-dissolution-gates
tsk-mt6z4kmu-9pgyta). This file began as the parallel session's RESEARCHED plan
(awaiting rulings); the user approved execution through a different session with
an amended plan (dissolution folded into unified-sim-executor), so record
research-vs-executed deltas here before trusting either document alone.

## Final placement map

| Source (contexts/execution/) | Destination | Research said | Executed |
|---|---|---|---|
| pipeline.py + build_paper_pipeline (+test) | services/execution/paper_pipeline_service.py | paper_pipeline.py | user suffix law won: *_service.py |
| paper.py PaperExecutionAdapter (+test) | services/execution/paper_execution_service.py | paper_execution_adapter.py | suffix law; ACL venue imports accepted |
| application/backtest.py (+test) | services/execution/backtest_service.py | paper_backtest.py | suffix law; run_paper_backtest name stable |
| exits.py (+exits_test, max_holding_exit_test) | domain/exit_rules.py (+tests) | services/execution/exits.py | DOMAIN — pure math, zero vendor imports after constant flip |
| exit_policy.py | FOLDED into domain/exit_rules.py (test → exit_rules_policy_test.py) | services/execution/exit_policy.py | single-consumer fold; proof test followed |
| nt_fills.py (+test) | DELETED — shell death | acl/nautilus/nt_fills.py | research claimed sole consumer paper_session.py; tree-wide grep found ZERO production callers at execute time — audit before moving residue modules |
| adapters/nautilus/{strategy_adapter,nt_compose,nt_backtest,hl_nt_capture}.py (+tests) | adapters/driven/acl/nautilus/ | same | agreed; 4 patch-string literals in paper_session_test.py rewritten too |
| __init__ shells, application/ports/** | DELETED | same | agreed |

## Canonicalization deltas from research

- EXIT_REASON_* taxonomy: research recommended DEFER; executed anyway because
  moving exits.py to domain/ made its acl/freqtrade import a purity violation.
  Flipped to canonical domain/exit_reason.py; ACL copy became a PURE RE-EXPORT
  SHIM so adapter-side consumers keep paths. Lesson: "defer" decisions on
  constants invert when their consumer changes layers.
- legacy_pickle._CANON: research said no remap needed; two transitive-retarget
  keys ADDED anyway (contexts.execution.{paper,pipeline} → services.execution.
  {paper_execution_service,paper_pipeline_service}) per campaign law. Cheap
  insurance beats re-verification bets.
- Tombstone test + _DISSOLVED_DOMAIN_FILES entry ("domain/exit_rules.py") +
  ARCHITECTURE.md rows all landed in the same commit.

## Verification evidence @84490a41

18 renames R087–R100 (both endpoints in pathspec-from-file), 32 files,
186+/354− · leftover grep CLEAN outside intentional _CANON keys · F821 one
pre-existing foreign hit (cli/app.py @HEAD) · ruff clean on 25 touched files ·
scoped suites green incl. junitxml-counted proofs battery · five failures +
one placeholder test (`pytest.raises(CatalogError): pass`) ATTRIBUTED FOREIGN
via pristine /tmp/head-proof worktree (parallel catalog/freqai sessions'
half-landed surface).

## Open items — Phase B of unified-sim-executor (READ BEFORE CONTINUING)

- Wave 0 EXECUTED 2026-08-24 — both leaves timed out at 600s with ZERO
  mutations; orchestrator absorbed both scopes. Landed as cb1fac99 (paper:
  PaperExecutionAdapter optional `cost_model` ctor arg, default None =
  byte-identical legacy fills; per-side fee_rate on FillEvent — market=taker,
  limit=maker, disabled model ⇒ 0.0; pipeline threads fill.fee_rate into
  OpenTrades.apply_exit → Trade.close(fee_rate=...); build_paper_pipeline
  gains cost_model kwarg. NT: HlFeeModel(FeeModel) in acl/hl/costs.py,
  `_hl_costs_enabled` gate + raw_config kwarg on build_backtest_engine,
  run_nt_backtest threads raw_config through; CME branch untouched).
- Wave 1 EXECUTED 2026-08-24, landed as 4ee14178: make_paper_cost_model
  factory (same hl_costs.enabled gate) + ExecutionContainer.paper_cost_model
  Singleton threaded through make_pipeline, which STAMPS the model onto the
  shared pipeline's PaperExecutionAdapter via dataclasses_replace (NOT a
  pipeline ctor kwarg — that raised TypeError across 21 composition tests
  before being caught). Non-paper executors untouched.
- Repair commit 7a9c48db (same day): 46 consumer files whose dissolution
  import rewrites were never committed — the fresh-reclassification misfiled
  them foreign after concurrent freqai commits touched them between passes.
  Worktree suites stayed green and masked it; PRISTINE /tmp/head-proof run
  failed collection and exposed the hole. Lesson promoted to SKILL.md:
  pristine-proof is a close-out GATE for every multi-file move wave.
- Tracker state at handoff: p6ais1 / 5skoo6 / u118uy all shipped with human
  verdicts citing SHAs; companion mission phase-a1/a2 (tsk-mt6z4kmu-*) still
  CLAIMED — need verify+ship closeout.
- Known blemish at tip: application_test::test_freqai_service_optional_when_disabled
  fails at 4ee14178 because the parallel session's test reached HEAD while its
  freqai_service.py implementation is untracked WIP — theirs to heal.
- Wave 2 pending: leaf-parity-proof (dual-host proof test/proofs/
  unified_executor_parity_test.py + ARCHITECTURE claim upgrade). Both hosts
  now share the gate: paper side via container-stamped adapter cost_model,
  NT side via build_backtest_engine(raw_config=...) — the proof should replay
  one deterministic fixture through run_paper_backtest and run_catalog_backtest
  asserting equivalence in BOTH gate states.
- Economics decision point: fee gate default-OFF preserves all historical
  numbers; user floated "fees forced ON everywhere" — NOT ordered; one-line
  spec change if they do.

## NT fee-model API notes (nautilus_trader 2.0.0rc2, probed live)

- FeeModel subclass needs explicit `def __new__(cls, model): return
  super().__new__(cls)` — Cython base __new__ rejects extra args.
- get_commission(order, fill_quantity, fill_px, instrument) → Money;
  implement get_commission_with_context as a delegating twin.
- Price/Quantity: use `.from_str()` (bare ctor needs precision arg);
  Money(float, Currency) constructor; instrument.quote_currency for HL.
- Venue string for HL instruments is `HYPERLIQUID` — gate compares
  `.upper() in {"HL", "HYPERLIQUID"}`.
- Probe these live in the venv BEFORE writing the wrapper; one interpreter
  round-trip saved three test-failure cycles.
