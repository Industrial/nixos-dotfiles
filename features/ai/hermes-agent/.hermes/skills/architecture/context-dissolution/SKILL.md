---
name: context-dissolution
description: >
  Dissolve a bounded context (contexts/<bc>/) in the andromeda package into
  services/, domain/, and adapters/driven/ per ARCHITECTURE.md. Use when
  consolidating a context behind application services, moving domain models
  out of contexts/, deleting a context tree entirely, or deciding where a
  type belongs during such a refactor.
tags: [architecture, ddd, refactoring, andromeda]
---

# Context Dissolution (andromeda)

Recurring refactor: eliminate `contexts/<bc>/` by relocating every type to its
proper layer. Completed so far: risk, session, candle, venue, microstructure,
instrument_map, freqai_host (2026-08-23), execution (2026-08-24). Remaining:
catalog only.

## Normative source

Read `python/andromeda/ARCHITECTURE.md` FIRST and again at execution time —
it changes (parallel agents update it). §1–§5 decide every placement dispute.

## Placement decision table

| Kind of thing | Destination |
|---|---|
| Plain dataclass with behavior over its own state (FSMs, records, engines, guards) | `domain/<snake_case>.py`, one class per file |
| Structural ports (Protocol consumed duck-typed by other contexts) | `domain/` beside the model that uses them |
| Type aliases duplicated across areas | Canonicalize in ONE domain file; others re-export |
| Orchestration / loop ownership / verb dispatch | `services/<area>_service.py`, one class per file |
| Pure helpers used by a service | Methods ON the service: staticmethod if pure, classmethod if it touches ClassVars, instance method if it reads self. NO module-level functions in a service file — the file defines exactly ONE class (explicit user rule) |
| Vendor/framework-coupled machinery (Nautilus Strategy subclasses, capture harnesses) | `adapters/driven/acl/<vendor>/` |

**Purity decides borderline calls:** if a candidate imports contexts/* or
adapters/*, it CANNOT be a domain model — make it a service (or split the pure
part out). This reversed two planned placements in practice (ForwardRunner,
MultiVenueRunner → services; MultiVenueRunner also typed on another service).

**Do not absorb a class into a service without counting production consumers**
(evidence via grep, not intuition): SessionRunner had multiple consumers and
stayed a service despite planning that assumed absorption.

## Hard invariants (enforce as tests)

1. **Tombstone:** `assert not (ANDROMEDA / "contexts" / "<bc>").exists()` in
   `test/proofs/ddd_layout_import_rules_test.py`.
2. **Purity gate:** dissolved-context domain files must import neither
   `andromeda.adapters*` nor `andromeda.contexts*` (list them explicitly in
   `_DISSOLVED_DOMAIN_FILES`).
3. Zero residual `contexts.<bc>` imports anywhere (grep to zero).
4. ARCHITECTURE.md gains a canonical Concern→Home table for the area.

## Procedure

1. Fresh-read every source being moved AT CUT TIME — sources drift between
   planning and execution (parallel agents); placements decided on stale reads
   will be wrong.
2. Enumerate importers: `grep -rn 'from andromeda.contexts.<bc>'` across prod
   AND tests; capture the exact import-line variants.
3. Move with `git mv` (preserves history). Delete the context `__init__.py`
   last, then remove the leftover `__pycache__` husk or the tombstone fails.
4. Rewrite imports with an ORDERED substitution script (most-specific splits
   first — e.g. one old module splitting into two destinations — then whole
   module moves longest-first). Verify zero leftovers by grep.
5. Canonicalize duplicate aliases discovered during the sweep.
6. Extend layout gates + docs table. Ruff --fix every touched file (import-sort
   and E501 fallout are certain), then scoped pytest.

## Verification discipline

- Scoped suite green before commit; ruff exit=0 on all changed paths.
- Attribution protocol when failures appear: rerun the failing tests on clean
  committed HEAD in a `/tmp` worktree. Failures reproducing there are
  pre-existing (document in commit message); failures only in the live tree
  belong to the parallel agent's WIP — never repair their half-landed waves
  except trivial mechanical completions (e.g. finishing their rename call sites)
  and say so in the commit message.

## Pitfalls

- **Parallel agent, shared index:** `git commit` commits the whole index —
  staged strays from the other session ride along. Stage explicit paths,
  re-check `git log` immediately before committing (HEAD moves underneath you),
  and note any riders in the message rather than rewriting shared history.
- **`git mv` bad source on freshly-verified paths = a parallel session already
  moved them.** Never retry; re-check `git log --oneline -2` + status, then
  follow the Concurrent-execution collision protocol in core/id-workflow
  (attribute committed/staged/mid-flight → read-only verify their state →
  outcome-annotate your plan artifact). Full walkthrough: execution case study.
- **Pickle remaps must cover anything reachable from serialized session state**
  — grep cannot prove a class is never pickled (the "PaperExecutionAdapter is
  obviously not pickled" call was wrong; `_CANON` needed the entry anyway).
  When in doubt add the remap mapping: it is inert if unneeded.
- **Never delete files outside the change set without asking** — the user
  denies unsolicited `rm` commands (probe files, worktrees stay until they act).
- **Import-path rewrites lengthen strings past line-length** (E501) — hoist
  repeated long module paths into a constant in test files.
- **devenv shell noise swallows piped stdout** — write command output to a temp
  file and print exit code + tail instead of relying on pipes/grep chains.
- Gate-bypass commits: only after proving pre-existing failures on clean HEAD;
  once per deadlock; evidence goes in the commit body.
- **Silent-fallthrough audit before promoting a canonical key:** grep configs
  and call sites for sentinel values that relied on the old lenient behavior
  (venue "synthetic" was a real kind in CLI/catalog/nautilus but absent from
  every normalizer). Sentinels join the canonical set; adapter edges keep an
  explicit degrade-not-raise catch for the new error while every other caller
  raises. Registry surfaces expose registration order (like
  PairlistService.available_methods) — tests must not assert sorted().
- `patch` on shared files can report "on-disk content differs" from a
  concurrent writer racing the read-back even though the write landed:
  re-read + `git diff` before retrying, never blind-retry.

## Case studies

See `references/case-studies.md` for the risk, session, venue, and execution
dissolutions (placement reversals, splits, consumer migrations, the
silent-fallthrough audit that preceded venue's canonical key, and the
concurrent-execution collision that defined the execution dissolution).
