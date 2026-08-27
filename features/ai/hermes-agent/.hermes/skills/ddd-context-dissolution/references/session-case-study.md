# Session dissolution case study (2026-08-23, commits 9a8a9535 → 16cda054)

The largest dissolution so far and the one that produced most of the SKILL.md
rulings. Kept here as the worked example; SKILL.md carries the generalized
rules.

## Timeline

- Wave 1 (`9a8a9535`): RiskService introduced — pair-lock book + singleton
  protection engines, identity tests per §5.4.
- Wave 2 (`65d4f099`): consumers migrated (make_api_app, ApiApp.locks field,
  locks_body); transitional `pair_locks` alias removed.
- Wave 3 (`521c9f49`): PairLocks class deleted; PairLock split into
  `contexts/risk/pair_lock.py`; exit-reason taxonomy moved to
  `domain/exit_reason.py` with the freqtrade ACL becoming a pure re-export;
  layout gate added; ARCHITECTURE.md risk table.
- Follow-up (`ba2932cb`): MaxDrawdownProtection joined the service
  (`observe_equity` driving SessionControl through the port) + `record_exit`
  fan-out returning per-engine engagement dict.
- Dissolution (`5a67dd52`): contexts/risk deleted entirely; PairLock, four
  engines, SessionControl/SessionStatus port moved to domain/ one-class-per-file.
- Session area (`c7b0e829`, then `bfc53619`): same pattern, plus the shell
  removals below.
- Single-class ruling (`0e7144fd`): ForwardSessionService module helpers folded
  into the class.
- Glue-module dissolution (`16cda054`): `services/forward_runner_support.py`
  deleted — pure math to `domain/session_warmup.py` (added to purity gate),
  QuestDB refill folded into `ForwardSessionService._refresh_store`,
  book_snapshot inlined into `ForwardRunnerService.snapshot`, and the
  `fe_warmup_bars` pass-through died by promoting catalog_backtest's
  `_freqai_fe_warmup_bars` to public (rename sweep followed into nt_backtest).
- Confession wave: `bfc53619` shipped with 9 latent failures — a truncated
  pytest log hid two F821s from the rename sweep plus 7 proofs still using the
  old wrapper kwargs. Full-directory proof runs + F821 audit caught them; both
  documented in the fix commit message.

## Plan corrections forced by evidence (all now in SKILL.md)

1. ForwardRunner planned for `domain/` — actually composes PaperPipeline
   (contexts/execution) and snapshots via the FT serializer (adapters/).
   Moved to services/ instead. Rule: if it composes pipeline/catalog/
   serializer, it is a service even if the plan said domain.
2. MultiVenueRunner planned for `domain/` — its registry is typed on
   SessionRunner, so it can't precede the gate decision into domain. Later
   deleted outright: zero production callers.
3. SessionRunner absorption was rejected mid-plan on consumer-count evidence,
   then ordered by the user after the shell removal made the wrapper pointless.
   Lesson: consumer counts inform, but "does this wrapper still have a reason
   to exist once X dies" is the sharper question.

## Shell-removal mechanics (bfc53619)

- Selector functions (`simulation_runner`/`real_runner`,
  `make_forward_runner`) replaced by direct DI:
  `providers.Selector(providers.Callable(runner_mode, run_config),
  simulation=providers.Factory(ForwardRunnerService, mode="simulation",
  pipeline=pipeline), real=...)`.
- Gate tests folded from the dead `session_runner_test.py` into
  `session_service_test.py`; the fold-in needed imports the source file had
  but the target lacked (CandleStore, OpenTrades, LongOnlyFixture, Pair,
  StakeAmount, Timeframe) — expect to add 4–6 imports when merging test files.
- The ft_17_77 smoke proof was rewritten against real behavior: N gated
  sessions in a plain venue-keyed dict at the call site.
- ARCHITECTURE.md table rows for deleted classes must be removed in the same
  commit; keep the Runner-port row (the port survives in domain/runner.py).

## Concurrent-session entanglement patterns observed

- The other agent landed SessionService (lifecycle verbs) while this session
  built RiskService; later they started the ApiApp state→sessions migration
  mid-verification (ApiApp gained `sessions: SessionService` before makers was
  updated — transient TypeError). Attribution via clean /tmp worktree run.
- Their staged-but-unstaged deletions rode along in our commits twice
  (runner_container.py deletion in ba2932cb, venue_service files in c7b0e829):
  read `git show --stat HEAD` after every commit and say so.
- A guard rename (dry_run_guard→guards, `live_submit_invoked`→`attempting_live`)
  landed with two stale call sites in ft_17_75 — finished the mechanical
  rename rather than re-litigating attribution.
