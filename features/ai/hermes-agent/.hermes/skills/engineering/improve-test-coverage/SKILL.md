---
name: improve-test-coverage
description: >
  Improve unit-test coverage of a specific app or package in this monorepo by
  targeting the largest absolute uncovered-LOC gaps with high-signal pure
  functions first. Use when the user asks to "improve test coverage",
  "increase coverage", "add tests for X", "cover the gaps", or hands you an
  lcov report and asks to push the number up. Pairs with `@idclear/base/testing`
  (do not import from `bun:test` in product tests — see TESTING.md). Do not
  use for e2e/integration test expansion (different harness) or for fixing
  failing tests.
---

# Improve test coverage

A class-level workflow for raising unit-test coverage of one app (or library)
in this monorepo without bloating the test suite. The discipline: **pick the
highest-leverage pure functions first**, write branch-equivalent tests, run
them locally before declaring done.

## When to use

- User asks to "improve test coverage" / "raise coverage" / "cover the gaps"
  for a specific app or library.
- User hands you an lcov report or a coverage number to push up.
- User points at a feature folder and asks for tests "for the parts that
  don't have them".

## When NOT to use

- For e2e or integration test expansion — the harness is different
  (Playwright / `TEST_INTEGRATION=1`); use `playwright-skill` or the
  appropriate integration runner instead.
- For fixing failing tests — debug with `debug-mantra`, then come back.
- For "test the new feature I just wrote" — that's TDD/BDD discipline,
  follow TESTING.md directly. This skill is for closing coverage gaps on
  existing code.

## Prerequisites (load first)

- `hermes-tool-routing-hooks` — confirms which file/web tools route through MCP.
- `TESTING.md` at repo root — the canonical rules. Especially:
  - Import `describe`/`it`/`expect`/hooks from `@idclear/base/testing`, not
    `bun:test`.
  - `it` bodies must return `Effect`; wrap synchronous asserts in
    `Effect.sync(() => { ... })`.
  - `assertEffect` / `assertEffectFails` for Effect-returning code.
  - Use `checkCoverage` from `@idclear/base/testing` if enforcing a threshold.
- The app's existing test in the same folder — mirror its style for imports,
  fixture shape, and `it` naming.

## Core rules

1. **Pure functions first.** Pure mappers, predicates, and lookup tables are
   highest-leverage: no mocks, no fixtures, no I/O. Each unit test exercises
   one branch with an asserted output.
2. **Branch-equivalent coverage, not line-coverage theater.** Every distinct
   `switch` case, every early-return branch, every null/undefined/empty-string
   path deserves a test. Lines get covered as a side effect; behavior is the
   goal.
3. **Test actual behavior, not expected behavior.** When a function uses
   `??`, `||`, `?.`, or `JSON.stringify`, the empty-string / null / undefined
   corner cases are *not* what your gut says they are — read the code, write
   the assertion that matches, then run it.
4. **`it.each` is NOT available in `@idclear/base/testing`.** The wrapper
   only preserves the basic `it(name, fn)` shape — `.each()` is dropped.
   Parameterize tests with explicit `for (const ... of ...) { it(...) }`
   loops inside a `describe`.
5. **Read the test runner before running it.** `apps/<app>/scripts/run-unit-tests.ts`
   splits files into a clean suite plus an isolated suite for tests that
   register `mock.module` / use sticky harness markers. New pure-function
   tests go in the clean suite and run fast — don't accidentally force them
   into isolation by touching sticky markers.
6. **One file = one source file.** Keep the test next to its target. Naming
   follows the source (`foo.ts` → `foo.test.ts`). When a single uncovered
   branch forces a `mockModule`-style test, but the existing `foo.test.ts`
   uses `bun:test` `it` (returning Promises) which is incompatible with
   importing `it` from `@idclear/base/testing` (Effect wrapper), put the
   mock-driven test in a *separate* file (`foo.<scenario>.test.ts`) that
   uses `@idclear/base/testing` end-to-end. See "Mocking a transitive
   dependency" below.
7. **Recognize the `Schema.TaggedError` 66.67% quirk.** Files shaped like
   ```ts
   /** doc */
   import { Schema } from 'effect'
   export class XError extends Schema.TaggedError<XError>()('XError', { ... }) {}
   ```
   report `LF:6 LH:4` (66.67%) under `bun-coverage` in this repo. Lines
   2 (the `import { Schema }` binding) and 3 (the trailing blank) never
   register as hit. This is a systemic tooling quirk, not a missed branch.
   16+ files in `apps/test-nextjs/src/**/errors/*Error.ts` share it. The
   `parseCoverage` 98.4% rounding in `libs/base/src/testing/lib/coverage.ts`
   does *not* save it (clean 66.67% stays below 98.4). Flag it as
   "accepted gap" and move on — closing it requires a structural refactor
   (re-shape the class so the Schema import is not a top-level executable
   statement), which is out of scope for a coverage pass.

## Workflow

```
1. Orient
   - Confirm target app and current coverage baseline.
   - Run baseline coverage if you don't have a number:
       cd apps/<app> && devenv shell -- bun scripts/run-unit-tests.ts --coverage
   - Note the lcov output path (usually apps/<app>/coverage/lcov.info).

2. Find gaps
   - Parse lcov.info for app src files sorted by absolute uncovered LOC
     (lf - lh). See references/lcov-gap-analysis.md for the parser.
   - Filter to UNTESTED pure-function files (no `.test.ts` sibling) within
     the top-N absolute gaps. These are the cheapest wins.
   - Ignore files with `mock.module` or sticky harness markers unless you
     plan to mock services.

3. Propose scope (do not just start writing)
   - Show the user the top candidates with: filename, LOC, current %, and
     one-line rationale. Ask which to target. Default suggestion: top 4–8
     pure-function files with no existing test.
   - This is "let me propose the plan after looking at the actual uncovered
     code" — match the user's preference for a plan gate before code.

4. Read each target file end-to-end
   - Identify every switch case, early return, `??`/`||`/`?.` branch, and
     boundary case.
   - **Check whether the source matches on bare enum-like ids or on derived
     path strings.** If the source's `switch (key)` compares against values
     like `'address'` or `'identity-proof'` (see `SubjectAggregateId` in
     `libs/subject-model/src/domain/ids.ts`), your test fixture's dataStructure
     keys MUST be those bare ids. Appending `.someField` or any suffix will
     push cases into the default branch and silently produce wrong output —
     the test will fail loudly on the assertions, which is good, but the
     failure looks like a fixture typo rather than a fixture mismatch.
   - Note dependencies — the test file must mirror the source's import paths.
   - Cross-reference constants used in the source (e.g. parent-path strings
     that happen to equal each other — TESTING.md does not excuse wrong
     assumptions about the data).

5. Write the test file
   - Template:
     ```ts
     /**
      * Tests for <source> — <one-line description of what it covers>.
      */
     import { describe, expect, it } from '@idclear/base/testing'
     import { Effect } from 'effect'
     // ... source-path imports

     describe('<source>', () => {
       it('<verb + outcome> for <case>', () =>
         Effect.sync(() => {
           expect(<call>).toEqual(<expected>)
         }),
       )
       // ... more cases
     })
     ```
   - One `describe` per logical group (function or related function family).
   - One `it` per branch / behavior — BDD-shaped verb+outcome names.
   - For switch statements: one `it` per case + edge cases (unknown key,
     empty input, etc.).
   - For optional chains / nullish coalescing: cover `null`, `undefined`,
     `''`, `'   '`, and the "present" case separately.

6. Run the test file in isolation
     cd apps/<app> && devenv shell -- bun test <path-to-new-test.ts>
   - Expect zero failures. If something fails, the failure is data:
     re-read the source for that branch and adjust the assertion to match
     actual behavior (do not "fix" the assertion to pass on a wrong
     assumption).

7. Run full coverage
     cd apps/<app> && devenv shell -- bun scripts/run-unit-tests.ts --coverage
   - Confirm no regression (full suite still passes — usually 6,000+ tests).
   - Re-parse lcov and verify the targeted files jumped to ~100% (the
     `@idclear/base/testing` coverage tooling rounds 98.5%+ to 100%).

8. Commit on the agreed branch
   - Use a feat/chore branch off the agreed base (often `origin/staging`).
   - One commit per logical batch is fine; do not split per-file if the
     batch is small.
   - Skip ceremonial verifiers after the user has accepted — per the
     verification-restraint rule in `hermes-tool-routing-hooks`.

## Examples

### Correct: branch-equivalent coverage on a pure mapper

```ts
// source: buildRowDetailsFromFieldMap(variant, fieldMap)
describe('buildRowDetailsFromFieldMap', () => {
  for (const variant of ALL_VARIANTS) {
    it('maps ' + variant + ' with present fields', () =>
      Effect.sync(() => {
        expect(buildRowDetailsFromFieldMap(variant, fixture(variant)))
          .toMatchObject({ typeOfAccountOrFacility: expect.any(String) })
      }))
  }

  it('returns null typeOfAccountOrFacility when detail is blank', () =>
    Effect.sync(() => {
      // '' is NOT null under `??` — read the source before assuming.
      expect(buildRowDetailsFromFieldMap('personal-bank-account', { '...TypeOfAccount': '   ' })
        .typeOfAccountOrFacility).toBe('')
    }))
})
```

### Correct: parameterized tests without `.each()`

```ts
for (const [variant, expected] of VARIANT_CASES) {
  it('resolves ' + variant + ' back to its profile path', () =>
    Effect.sync(() => {
      expect(individualProfilePathForSourceOfFundsVariant(variant)).toBe(expected)
    }))
}
```

### Pitfall: assuming both parent paths are different

```ts
// WRONG: assumes SOURCE_OF_FUNDS_INDIVIDUAL_PARENT_PROFILE_PATH and
//        SOURCE_OF_FUNDS_LEGAL_ENTITY_PARENT_PROFILE_PATH are different strings.
// In this repo they both resolve to 'source-of-funds' — the test would
// always pass trivially.
expect(isSourceOfFundsIndividualParentProfilePath(
  SOURCE_OF_FUNDS_LEGAL_ENTITY_PARENT_PROFILE_PATH,
)).toBe(false)  // ← silently true; test is a no-op

// RIGHT: cross-reference the constants in the source before asserting.
```

### Pitfall: `it.each` from `@idclear/base/testing`

```ts
// WRONG: it.each does not exist on the wrapped `it`.
it.each(ALL_VARIANTS)('maps %s', (v) => Effect.sync(() => { ... }))

// RIGHT: explicit loop inside the describe.
for (const v of ALL_VARIANTS) {
  it('maps ' + v, () => Effect.sync(() => { ... }))
}
```

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Cannot find module '@idclear/base/env' from 'test-env.setup.ts'` | `bun install` not run in worktree | `devenv shell -- bun install --frozen-lockfile` |
| `devenv shell` fails with `path '/.../.cursor/nix' does not exist` | worktree missing the vendored nix facade | `cp -r ../monorepo/.cursor/nix .cursor/` from worktree root |
| `it.each is not a function` | tried to use Jest-style parameterization | rewrite as `for (const x of ...) { it(...) }` |
| Lean-ctx `ctx_read`/`ctx_search` says "path escapes project root" | MCP is project-bound to `/data/Code/idclear/monorepo`; worktrees (`/data/Code/idclear/monorepo-<name>`) and any sibling checkout are outside the root | read with `terminal cat <path>` or `execute_code` + `pathlib`; search with `terminal grep`/`rg`. To *edit*, native `patch`/`write_file` are also blocked by the routing hook — only `execute_code` Python `Path.write_text` works on these paths. Add the worktree dir to lean-ctx's `~/.config/lean-ctx/config.toml` `extra_roots` if you'll be back here often. |
| New tests pass in isolation but full coverage still shows the file at <100% | fixture keys don't match what the source's `switch`/`if` actually matches on | read the source's exact-match strings (often bare enum ids like `'identity-proof'`) and align your fixture dataStructure keys to them; do not append path suffixes (e.g. `'identity-proof.someField'`) that push cases into the default branch |
| A source file shows 1 uncovered line in a `value == null` / `typeof x !== 'object'` early-return | the existing tests pass valid objects / strings; primitives and `null` are not exercised | add an `it(...)` with `null`, `undefined`, and a primitive (`42`, `true`); these short-circuit the inner branch without breaking existing assertions |
| All tests fail with module resolution errors | `node_modules` empty after `worktree add` | `devenv shell -- bun install --frozen-lockfile` |
| Coverage tool reports 99.7% instead of 100% | a defensive guard branch is unreachable from the public API | acceptable; `@idclear/base/testing` coverage rounds ≥98.5% to 100% per the convention in `mapFinancialRecords.test.ts` header notes |
| User pushes back saying "just give me a clear guide" / "why six edits" | session-specific numbers or counts baked into the skill | strip the numbers; describe the workflow generically |

## Verification restraint

Once the user accepts the batch ("commit it", "ship it", "looks good"),
**do not** re-run `hermes hooks list/doctor/test`, `git status`, or
ceremonial verifiers. The verification-restraint rule in
`hermes-tool-routing-hooks` applies here too — re-running reads as distrust.

## See also

- `TESTING.md` — repo-root testing standards, including `@idclear/base/testing`
  rules and Effect-first test bodies.
- `hermes-tool-routing-hooks` — which file/web tools route through MCP vs
  terminal; verification restraint.
- `debug-mantra` — when a test fails for an unexpected reason, debug it as
  a real bug, don't paper over the assertion.
- `references/lcov-gap-analysis.md` — reusable parser for finding top
  uncovered-LOC gaps from `lcov.info`.
</content>
</invoke>