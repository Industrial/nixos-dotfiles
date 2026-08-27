# Runner consolidation case study (2026-08-23)

SessionService → RunnerService contract, shell deletions, and the repair
trail. Read alongside SKILL.md rulings before touching services/runner/.

## End state

INTENT at merge time (2026-08-23); verify against the worktree before
planning follow-ups — ctx_tree services/runner/, don't trust this block:

```
services/runner/
  runner_service.py                  # RunnerService(ABC)
  forward_runner_service.py          # ForwardRunnerService(RunnerService)
  forward_runner_service_test.py     # relocated from services/session_service_test.py
```

The flat-class leftover was EXECUTED 2026-08-23 (commit 16b6af04): git mv
ForwardRunnerService into services/runner/ (~15 import sites across
composition/http/nautilus/backtest/proofs + both __init__ re-exports +
ARCHITECTURE.md row), `_n_bars = 0` initialized in __init__, and
dispatch_bar/snapshot_trades now genuinely degrade when pipeline is None
(docstring promise made true; asserts deleted) — all inside the rename
commit so rename detection held at 93% similarity.

FOLD WAVE EXECUTED 2026-08-23 (commit d1479124) — supersedes the "stays put"
ruling below: user ordered ForwardLoopService folded INTO
ForwardRunnerService ("ForwardRunnerService seems like an empty service;
shove all the functionality in there"). Loop deps optional via idempotent
`configure_loop()`; make_forward_session wires and returns THE runner
singleton; services/forward_loop_service.py deleted.

## COLLAPSE WAVE EXECUTED 2026-08-23 (commits 1827100b + affb4cad) — supersedes the package layout above

User asked THE design question with only one subclass left: "should there be
more than one subclass of RunnerService at all, or should all run types
(backtest, paper, live) use the same RunnerService? Move everything into it,
make it the one and only, put the file in services/, clean up services/runner."

Answer that held up: NO second subclass. Evidence — backtest drives the
Nautilus BacktestEngine directly and never constructs a runner; paper/live
shared exactly one implementation. An ABC with a single child is speculative
generality, and this repo's law says shell classes die. The subclass axis
(feed) never produced a second member because variance was already handled
by injection: execution axis = pipeline's venue adapter, feed axis =
configure_loop. The ABC's shared surface (FSM verbs, hooks, gated on_bar,
venue_executor/dry_run surface) was INLINED into the concrete class — no
dead base kept.

Final shape:
```
services/
  runner_service.py                  # RunnerService — concrete, no subclasses
  runner_service_test.py             # moved beside its subject (rename 91%)
```

Mechanics worth keeping:
- git tracks the collapse as renames: forward_runner_service.py →
  runner_service.py (77%) and the test (91%); the package __init__ shows as
  delete mode. Committing new untracked files requires `git add` FIRST —
  `git commit -- <pathspec>` ignores untracked paths entirely (error:
  "pathspec did not match any file(s) known to git").
- Relocated-test path bug: `Path(__file__).parents[N]` config lookups must
  drop one level when the test moves UP a directory level
  (parents[2] → parents[1]); symptom is FileNotFoundError on configs.
- Hand-composing a class from two files can DROP AN IMPORT each source had:
  CatalogError was lost in composition → ruff F821 on both except clauses,
  latent (both except-paths unreachable under synthetic/mocked tests).
  Ruff every file you hand-compose; pytest cannot catch unreachable-path
  NameErrors.
- ARCHITECTURE.md: merge the contract+subclass rows into one row describing
  the single service and WHY there are no subclasses (execution varies by
  injected pipeline adapter, feed by configure_loop; backtest drives Nautilus
  directly) — this pre-empts the next "why isn't X part of Y" question.
- The rename commit landed mid-sequence AGAIN (their tombstone wave absorbed
  parts of the diff for the third time); per-file classification against
  current HEAD before committing caught it. Sanitize-restore applied to
  backtest.py (their loader flip) and services/__init__.py (their new
  MicrostructureService export) — both restored pending in finally.

Still-open by choice after collapse: nothing — venue_executor/venue_submit
guarding question died with the base class (the concrete class guards
pipeline=None everywhere).

## Fold-wave lessons (ForwardLoopService → ForwardRunnerService, d1479124)

RunnerService owns: SessionState FSM, FreqUI verbs (start/pause/resume/stop/
apply_action), admission gate `on_bar` as template method
(stopped→raise / paused→None / hooks / allowed_pairs / store.ready /
dispatch_bar), venue_executor + dry_run + venue_submit surface.
Subclass seams: `mode` (RunnerMode attr), `dispatch_bar(store)`,
`snapshot_trades()`. ForwardRunnerService adds pipeline-backed dispatch,
FT snapshots, note_bars. pipeline=None tolerated for verb-only API use.

Container: `runner = providers.Selector(Callable(runner_mode), sim=Singleton,
real=Singleton)`; legacy aliases `session_service/session_runner/
runner_service = runner` kept because application_container and proofs still
use them. ForwardSessionService dropped its separate session_runner field —
drives self.runner; journaling (`pipeline.on_trade_closed =
runner.closed_trades.append`) restored in __post_init__ after merge dropped it.

Deleted: services/session_service.py(+test), MultiVenueRunner(+test),
SessionRunner, make_session_gate, make_forward_runner,
simulation_runner/real_runner selectors.

## Debate history that became law

1. User asked difference between SessionService and ForwardSessionService;
   principle offered: a session behaves identically in backtest/paper/live.
2. User asked "isn't Driver just a Runner?" — conceded push/pull split was
   the only distinction and a formal Driver protocol would be ceremony.
3. User ordered RunnerService per the VenueService model ("single central
   service contract... implementations figure out the differences").
   Clarify choice locked: feed-axis subclasses (forward/replay), sim/real via
   injected executor, SessionService dissolves INTO the base.
4. Same user later ordered the COLLAPSE once the subclass count hit one:
   the hierarchy principle ("one contract, implementations differ") does NOT
   protect a hierarchy with no second member — speculative generality loses
   to "shell classes die" when the evidence shows only one implementation
   and zero backtest usage. Hierarchy orders are reversible by their own
   author when the variance argument evaporates; don't defend yesterday's
   structure today.

Lesson for future hierarchy proposals: user reasons from "one door per
topic"; counter-arguments about polymorphism not being exercised at runtime
lose once they order it. Execute literally, keep the debate out of code —
and expect the reverse order just as literally when only one door remains.

## Repair trail (each cost a pytest cycle)

- Property-vs-attr trap: ABC declared `mode` @property; subclass __init__
  assigned it → AttributeError 'property has no setter'. Fix: plain annotated
  attr on ABC.
- Regex collapse of nested ctors mangled comma-containing kwarg values
  (frozenset({..}), StakeAmount.parse(100), build_paper_pipeline(...)) leaving
  `)),` orphans → SyntaxError at COLLECTION in ft_17_03/06/26/36/54. Fix:
  hand-repair each; always run `pytest --co -q` after such sweeps.
- Provider-name whack-a-mole: dropping session_runner then runner_service
  providers broke collection tree-wide ('DynamicContainer object has no
  attribute'). Fix: alias all three legacy names to `runner`.
- Deleted factories had unseen importers: make_session_gate used by nautilus
  test helpers AND re-exported via composition/application.py import lists;
  make_forward_runner resurrected by paper_session_run_test +
  forward_session_trade_persistence_test. Grep composition/application.py
  re-export list on every deletion.
- Twin-instance hazard surfaced as real bug: harness built gated runner +
  verb-only twin over one FSM, and ForwardSessionService kept BOTH
  session_runner and runner fields → missing-kwarg TypeErrors and a journaling
  identity failure (pipeline.on_trade_closed is runner.closed_trades.append).
  Fix: one field, sessions=runner everywhere.
- Test-harness signature drift: second _harness variant passed
  state=SessionState() instead of container.session_state() — singleton test
  caught it. Keep identity assertions when porting tests.

## Fold-wave lessons (ForwardLoopService → ForwardRunnerService, d1479124)

- Circular import is the signature hazard of folding a loop service into a
  runner subclass: the runner module is imported BY contexts (backtest.py),
  so its module-level import of catalog_backtest — which transitively
  re-imports the runner via backtest.py — now cycles. The old two-module
  split hid it. Fix: defer the cycle-edge import into the method that uses
  it (`_refresh_store`) with a comment saying why. Probe BOTH directions
  after any fold (`import runner_module` AND `import contexts...backtest`)
  before running tests.
- Fold mechanics that kept every constructor call site valid: keep the
  RunnerService ctor untouched, init all loop deps to None/empty in
  __init__, add one idempotent `configure_loop()`; make_forward_session
  becomes wire-and-return-singleton; SessionContainer's forward_session
  Factory keeps working unchanged because it already received the runner
  twice (`runner=` + `sessions=`). cli/app.py and provider-override tests
  needed ZERO edits.
- Persistence-test C2 assertions flip meaning on a fold: `forward.runner is
  container.session_runner()` becomes `forward is container.session_runner()`
  — rewrite them as identity checks on the merged object rather than
  deleting (they are the regression locks for the twin-instance hazard).
- Race protocol that worked end-to-end: pin HEAD at every script start and
  abort if it moved; classify each commit path against CURRENT HEAD
  (whole / sanitize-to-HEAD+my-delta+restore-in-finally / skip-if-absorbed);
  stash foreign dirty files ONLY for the validation moment
  (`git stash push -- <path>` then `pop` in finally) when their WIP poisons
  your test run; commit history-safely with pathspec + SKIP env. When the
  parallel agent's wave breaks collection tree-wide mid-session, wait in
  bounded poll loops for their commit instead of repairing files they hold.
  One confession duty: a guard crash between sanitize and restore silently
  dropped their in-progress comment edit in a shared file — always pair
  sanitize with try/finally restore IN THE SAME script run.

## Verification pattern that worked

pytest --co -q first after mechanical sweeps; then scoped suite
services+composition+proofs+nautilus+http (--ignore cli); ruff --fix on
touched paths; full-log grep for FAILED (never tail alone). Final green:
115 passed.

## EXECUTED 2026-08-24: services/runner/ package + (same day, later) the ABC REVERSAL

Trigger was a NAME-COLLISION question, not a hierarchy request: "why is there
a backtest_runner.py in services/catalog? Don't we have runner_service.py?"
Recon showed two different jobs sharing the word runner — batch QuestDB→NT
one-shot backtest job (free functions, 5 call sites) vs the gated live loop
(class, 21 consumer files) — plus a latent cycle (runner_service defers
importing warmup helpers FROM backtest_runner; pure math both need).

Wave 1–4 EXECUTED uncommitted (plan .cursor/plans/runner-services-package.plan.md):
package scaffold, family git-mv, `LiveRunnerService` rename inside live_runner.py,
facade alias `RunnerService = LiveRunnerService` in runner_service.py keeping every
consumer import AND patch string valid with zero call-site edits; warmup math →
domain/session_warmup.py (+ session_warmup_test.py ported from backtest_runner_test)
killing the deferred-import cycle; HistoricalRunnerService(catalog=None) class with
run()/ensure_micro(), consumers cut over incl. ~15 test seams repointed to
class-seam shape (`"...HistoricalRunnerService.run"` string targets — module-attr
patches die when a free function becomes a method, and fakes must be arity-tolerant:
a plain function patched onto a CLASS becomes bound and self arrives first);
layout gate test_runner_package_consolidated; ARCHITECTURE.md rows.

THEN the user ordered the ABC REVERSAL (supersedes BOTH the collapse wave AND the
facade): "We need a RunnerService (runner_service.py) as base class with abstract
methods, LiveRunnerService (live_runner_service.py) and HistoricalRunnerService
(historical_runner_service.py) inherit from it." Note the filename suffix law won:
files are <name>_service.py, so the earlier live_runner.py/historical_runner.py
names lived for hours only. Final shape:

```
services/runner/
  __init__.py                       re-exports all three names
  runner_service.py                 class RunnerService(ABC) — abstract verbs only, NO ctor;
                                    annotated attr `mode: RunnerMode` (NOT @property — trap recurred)
  live_runner_service.py            class LiveRunnerService(RunnerService), behavior verbatim
  historical_runner_service.py      class HistoricalRunnerService(RunnerService); trivial honest
                                    verb overrides (status()→"stopped", history()→(), snapshot()→
                                    SessionSnapshot(trades=[],n_bars=0,n_trades=0)); lifecycle verbs
                                    raise BotControlError("historical runner has no session …")
  runner_service_test.py            hierarchy + ABC-instantiation-raises-TypeError + verb tests
  live_runner_service_test.py       renamed from live_runner_test.py (parents[1]→parents[2] fix again)
```

Key mechanics of the reversal:
- Identity preserved by SUBCLASSING, not aliasing: every existing `RunnerService`
  annotation/construction keeps working because instances ARE RunnerServices now.
  But direct CONSTRUCTION sites must name the concrete class — dependency_injector
  Singleton(RunnerService, ...) raises "takes no arguments" on an abstract base.
  Swept: session_container Selector arms ×2, http/app fallback ctor (found a
  pre-existing DUPLICATE import line there), execution/backtest_service, ~10 proof
  files + application_test/paper_session*_test ctors.
- Staticmethod helpers called as Class.static() in tests (_excluded_pairs,
  _warming_metrics) moved WITH the class: patch seams repointed RunnerService→Live.
- Unused base imports left behind in proofs after ctor cutover → F401 sweep; docstring
  mentions of "RunnerService" do NOT count as uses (check code lines only).
- git mv refuses UNTRACKED files (created this session, never committed) — plain
  filesystem move for those, git mv only for tracked ones.
- Mid-wave the parallel freqai session landed their full-absorption ruling
  (services/catalog/* folded INTO catalog_service.py, package deleted) and refactored
  paper_session.py to facade verbs (micro_lookup/download_bars) — test seams I'd just
  repointed needed a SECOND pass onto CatalogService.micro_lookup. Expect moving
  targets when two sessions share an area; re-grep seams before each gate run.

Out of scope, recorded to prevent confusion: Rust crates/backtest-runner
(unified-backtest-runner-spa mission, different subsystem, same word) and
run_paper_backtest test-double (execution-area paper harness).

ABC REVERSAL REPAIR TRAIL (each cost a gate cycle, 2026-08-24):
- dependency_injector Singleton(RunnerService, ...) → "TypeError: RunnerService()
  takes no arguments" (abstract base, no ctor). Fix: session_container Selector
  arms ×2 + http/app fallback ctor + backtest_service + ~10 proof files construct
  LiveRunnerService now; type annotations on the base stay valid everywhere.
- http/app.py carried a PRE-EXISTING duplicate `from andromeda.services import
  RunnerService` line — dedup while repointing.
- partial_failure_test reached staticmethods via `_M = RunnerService` alias +
  function-local `import ... as _FS/_FW` → AttributeError '_excluded_pairs'.
  Static helpers live on the concrete class; repoint alias AND local imports.
- paper_session_test had BOTH seam shapes: string patches (`_PS +
  ".load_catalog_micro"`) and object-form setattrs — all needed the facade-verb
  repoint (CatalogService.micro_lookup, arity-tolerant lambdas), twice, because
  the parallel session refactored paper_session.py to facade verbs MID-WAVE.
- paper_session_run_test used patch.object(ps.RunnerService, "on_ws_tick") —
  base has no on_ws_tick; ps module must import LiveRunnerService for that seam.
- app_main_test's require_from_env stub returned a bare `type("S", ...)` instance
  lacking micro_lookup once ensure_micro routed through it — stubs must grow every
  verb the code path touches (grow-the-fake, don't shrink the path).
- Unused base imports in proofs after ctor cutover → F401 cleanup; docstring-only
  mentions ("H2: RunnerService never calls pipeline…") are NOT uses.
