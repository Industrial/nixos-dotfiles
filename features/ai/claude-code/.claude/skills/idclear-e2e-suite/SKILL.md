---
name: idclear-e2e-suite
description: >-
  Running the Playwright E2E suites in the idclear monorepo (apps/e2e-test):
  the serial runner, compose-stack prerequisites, devenv wrapping, subset runs,
  abort semantics, failure artifacts, and known env pitfalls. Load when asked
  to run, re-run, or triage e2e tests in this repo.
---

# idclear e2e suite

Playbook for exercising `apps/e2e-test` against the docker-compose stack
(Traefik serving `idclear.localhost`). Covers running and triaging; fixes to
app code are out of scope until a failure is diagnosed.

## Commands (always via devenv)

bun is not on the host PATH on the NixOS dev box — every bun/playwright
invocation goes through devenv (stable repo convention, not a transient issue):

```bash
cd apps/e2e-test
devenv shell -- bun run test:e2e:serial   # bin/e2e-serial.sh — the default full run
devenv shell -- bun run test:e2e          # --fully-parallel; rarely wanted locally
devenv shell -- bun run test:e2e:list     # enumerate without executing
```

Run a subset while preserving the dependency-safe forward order (the script
accepts spec paths as args, applied over its 66-entry default list):

```bash
devenv shell -- bash bin/e2e-serial.sh tests/rule-engine/onboarding-guards/ru-residency-permit.spec.ts
```

Launch docker/devenv invocations through the native Hermes `terminal` tool —
lean-ctx `ctx_shell` allowlists reject `docker` (see hermes-tool-routing-hooks).

### Grading sweep — run ALL specs, then relabel `#`/`##`

The script's own loop aborts on the first red spec (`set -euo pipefail` +
`--max-failures=1`), so a plain run can never grade the whole list. To grade
every entry in one pass, drive one e2e-serial.sh invocation per spec with
failures allowed — proven driver (writes `results.tsv` with
`<exit-code>\t<spec>` rows plus a per-spec `full-run.log` into
`apps/e2e-test/.e2e-sweep/`, never aborts early):

```bash
devenv shell -- bash .hermes/skills/workflow/idclear-e2e-suite/scripts/sweep-all-specs.sh
```

Then relabel `DEFAULT_E2E_SERIAL_SPECS` per the convention in the script's
header comment: `##` prefix where rc≠0, `#` where rc=0. A full 66-spec pass
took ~1.5–2 h (Aug 2026) — launch via Hermes
`terminal(background=true, notify_on_complete=true)` and poll the tsv; note
Hermes reports the wrapper's exit code, read the results file for truth.
Failure-cluster snapshot from the last full sweep:
`references/full-sweep-2026-08.md` (stale by definition — re-grade first).

## What bin/e2e-serial.sh does automatically

- Exports `CI=true`, `E2E_RETRIES=0`, and compose-mode flags (`E2E_START_NG_CLIENT=0`,
  `E2E_START_TEMPORAL_WORKER=0`, `E2E_SKIP_DB_SEED=1`) so the compose stack serves
  the app; playwright.config.ts then skips spawning dev servers / a temporal worker.
- Syncs `/run/idclear-env/.env.development` from the running test-nextjs container
  into host `.env.development` (Logto credentials).
- Force-recreates test-nextjs if the container's `LOGTO_TESTNEXTJS_APP_ID`
  drifts from the mounted volume env.
- Configures the Logto mock email connector (`CI=true`) and waits for logto health.
- Reseeds rule graphs (`scripts/reseed-rule-graphs.sh`) when the batch includes
  rule-engine / SoW-evidence specs.
- Health-gates logto + test-nextjs before EVERY spec (long wait + one restart).

Startup fails fast if `NG_CLIENT_BASE_URL` / `RISK_CALCULATOR_URL` are unset —
they come from workspace-root env files via `loadEnv()` in playwright.config.ts.

## Abort semantics — expect early stops

The script runs `set -euo pipefail` and each spec with `--workers=1
--max-failures=1`: ONE failing spec aborts the entire run, leaving the rest of
the 66 specs unexecuted. A red run usually means "first failure found", not
"suite broken". Find the failing spec in the log, then resume by passing the
remaining spec paths as args once resolved.

## Failure artifacts

- Per-spec artifacts land in `apps/e2e-test/test-results/<spec-slug>-chromium/`:
  `trace.zip`, `video.webm`, `test-failed-N.png`, `error-context.md`.
- `test-results/` is WIPED by every subsequent playwright invocation — only
  the last failing run's artifacts survive. After reproducing a failure, read
  `error-context.md` immediately: it holds the aria page snapshot at the
  failure moment and is usually faster ground truth than the trace (it
  exposes e.g. "No data items yet" empty states and which wizard step was
  actually active — things the error text alone won't tell you).
- Inspect a trace: `devenv shell -- bun x playwright show-trace <trace.zip>`
  (run from apps/e2e-test). Aggregate results: `bun run analyze:test-results[:json]`.

## Known pitfall: verification-code "(mock file)" failure

RESOLVED (Aug 2026): the volturapay-embed-full-onboarding failure was misdiagnosed
as env-wiring. Real cause: the spec passed a themed PEP label
(`VOLTURAPAY_PEP_NOT_APPLICABLE_LABEL`) the wizard never renders — the gather
wizard serves canonical catalog labels (`Level 1-4` / `Non Applicable` from
`PEP_STATUS_FIELD_OPTIONS` / `libs/common pep.enum.ts`); the
`libs/theme volturapayPepValues` set has zero consumers. The unmatched label
made `selectFirstPepAnswer` fall through to the hidden native radio input →
surrounding `<fieldset>` intercepts pointer events → click timeout. Fixed in
commit 34ff7a3b7 (use default label, drop dead constant). The env-wiring class
still applies to other specs: `playwright.config.ts` calls
`stripLogtoMailgunEnvForTests()` at load time, so `LOGTO_MAILGUN_*` never
reaches the e2e process via config; `lib/logtoVerificationEmail.ts` reads the
mock file first, then Mailgun.

## Wizard DOM facts (learned the hard way, Aug 2026)

- Prior wizard steps stay MOUNTED in the DOM: radio `isVisible()` probes hit
  stale steps forever. Dispatch on the active step heading
  (`dg-step-title-default` textContent) instead of radio visibility.
- Radix radio groups: `getByRole('radio', {name})` clicks work (the role=radio
  button); `locator('input[type="radio"]')` matches the sr-only aria-hidden
  native input inside a `<fieldset>` that intercepts pointer events — clicking
  it times out.
- Effect API misuse in specs/page objects: `Effect.promise(fn)` takes a
  `() => Promise` factory — passing it an Effect (`Effect.promise(() =>
  someEffect)`) fails at runtime with `TypeError: evaluate(...).then is not a
  function`. Inside `Effect.gen`, just `yield* someEffect` directly; reserve
  `Effect.promise`/`Effect.tryPromise` for raw async callbacks. Cost two
  failed e2e runs before diagnosis (Aug 2026).
- Failure screenshots are directly readable: `test-failed-N.png` in the
  test-results dir shows the exact wizard step, selected options, and Next
  button state at failure — feed the path to the vision tool instead of
  guessing from logs. Faster and more reliable than re-running to reproduce.
- Radio steps (PEP, Net Worth, Expected Activity Level) keep Next disabled
  until an option is chosen; a walk-forward loop must answer them.
- Stale test expectations: `wizardMyDataDetailExpectations` asserted an
  other-name "Alias" and secondary nationality, but the Name aggregate is a
  single `{firstName, lastName, fullName?}` record and the wizard fills only
  primary data → "detail panel missing Alias" timeouts (fixed 93fa4a9e1).

## Known pitfall: stale compose image

`test-nextjs` is compose-BUILT (`build: context: .`) and can silently predate recent
app-side commits — failures then look like app bugs but are just an old image. Check
before triaging app-side failures:

```bash
docker compose exec -T test-nextjs stat -c %Y /app/apps/test-nextjs/.next/BUILD_ID
git log --since=<that UTC time> --oneline -- apps/test-nextjs libs
```

Rebuild with `docker compose build test-nextjs && docker compose up -d test-nextjs`
(background; wait for `(healthy)`), then run ONE e2e invocation WITHOUT
`E2E_SKIP_LOGTO_MOCK_SETUP` — recreating the container invalidates the Logto mock
connector setup and registration codes fail with "(mock file)" until reconfigured.

## Page-object drift (admin cases hub, fixed Aug 2026)

Recurring archetype: a single `isVisible()` snapshot, then an unconditional
`waitFor(<legacy ng-client selector>)`. The snapshot races the mount, falls through, and
the legacy selector never appears → 30s timeout. Fixes that landed (all verified green):

- `waitFor(a.or(b).first())` disjunctions instead of snapshot-then-fallback
  (AdminCaseDetailPage assertDetailVisible: 'Access and assign' is a BUTTON now, not a
  heading; waitForCaseRowById: `cases-table-select-<uuid>` .or. legacy `span[title=]`).
- Retired ng-client surfaces: `?id=`/`?search=` URL params (case UUID now lives in the
  path `/admin/cases/<segment>/<caseId>`; search lives in the sidebar input
  `cases-hub-search-input-input`), `nav-case-tab-N`, `case-detail-back`, `.caseList
  span[title=]`, `.sidebar-wrapper .stateList`, `alt-select.expandable-sidebar-select`.
  Back-navigation = click the sidebar Queue link for the segment, fallback `page.goBack()`.
- Assignee filter: options render as `<username> User` (filter by `demo.researcher1`, not
  display names); hidden on the unassigned segment by design (casesHubFilterLayout); the
  hub can land with `?assignedTo=<self>` preset hiding seeded fixture cases —
  `clearAssigneeFilter` picks 'All users' and the UI keeps `?assignedTo=all` in the URL
  (wait for param==='all' or absent, not param absent).
- Hidden nodes: mobile list-card variants (`lg:hidden` wrappers) duplicate desktop text;
  getByText resolves them but toBeVisible times out ("unexpected value hidden") — prefer
  URL/testid assertions.
- URL regex anchors: `toHaveURL(/segment(\/|$)/)` breaks when the app appends
  `?assignedTo=…` — don't anchor.

Full per-archetype recipes: `references/failure-triage-playbook.md`.

## Fixture repair: seeding My Data identity data (RESOLVED Aug 2026)

`demo.supervisor` had zero My Data rows under compose (`E2E_SKIP_DB_SEED=1`)
→ "No data items yet" (my-data/01-05) and profile-settings failures. The
my-data BDD specs only need ≥1 list row (ideally a Name row) with a working
View panel. Recipe that made my-data/01–05 green:

1. Subscribe the user via seed 0806 (app code, safe) inside temporal-worker —
   mirror `scripts/reseed-rule-graphs.sh`, swapping in
   `seedOnboardingBaseUsers` wrapped in `withForkedRequestEntityManager(...)` +
   `Effect.provide(SeedAppLayer)` (plain `SeedAppLayer` alone fails with
   "Service not found: EntityManager"). Creates the `subject_products` row.
2. Insert identity rows via psql (db `risk` on yb-pg:5433). ID GRAIN MATTERS:
   - `subject_names.subject_id` / `subject_nationalities.subject_id` =
     `subjects.id` (internal uuid)
   - `subject_products.subject_id` / `identity_personal_details_gather.owner_id`
     = platform subject id (= the user's `real_identity_subject_id` /
     active profile id)
   - `identity_personal_details_gather.subject_product_id` = the 0806 product
   - payload jsonb: `{"fields": {"identity-profile.pep-status":
     "non_applicable", "identity-profile.date-of-birth": "1985-06-15"}}`
   Write the SQL to a file and `docker cp` + `psql -f` (inline quoting of
   jsonb in `sh -c` breaks).

## In-container Effect probes (app-code debugging without dev mode)

To verify/refute an app-side read path against the real DB, run the actual
functions inside the temporal-worker container (has bun, app source, node_modules,
and env) instead of tracing statically:

```bash
docker compose exec -T temporal-worker sh -c '
  set -a; . /run/idclear-env/.env.development; set +a
  cd /usr/src/app/apps/test-nextjs
  timeout 90 bun ./probe.ts'
```

Probe script requirements (learned by trial, Aug 2026):

- Put the script INSIDE `apps/test-nextjs/` (workspace dep resolution — `/tmp`
  fails with "Cannot find module '@idclear/db'").
- Static imports only; wrap in
  `withForkedRequestEntityManager(program).pipe(Effect.provide(SeedAppLayer))`
  (plain SeedAppLayer lacks EntityManager).
- Use the app's own helpers (`emFindOne`, `makeOrmErrorMapper`) — raw Mikro
  `em.findOne` isn't in scope via the EntityManager tag.
- Building the full `ServerAppLayer` graph in a probe hits missing services
  (AuthenticationService, DataCatalog, DataRepository) — probe the narrowest
  layer instead (queries + mappers), and treat "works in probe, fails live" as
  evidence the bug is in session/auth wiring, not the data layer.
- MikroORM jsonb columns arrive as OBJECTS (not strings) — the app's payload
  parsers already handle both.
- Clean up probe files afterwards; ask before `docker exec rm` (destructive).

## Known app-side failure clusters (sweep 3, Aug 2026: 45 pass / 21 fail)

Sweep-3 state after the page-object + fixture rounds. Remaining failures are
three app-side root causes, each verified with DB/log/screenshot evidence
(verification recipes: `references/serial-failure-triage.md`):

- My Data detail panel 404s on PEP records: `NotFoundError
  dgr1:identity-profile:<gatherRowId>:identity-profile.pep-status`. Row,
  owner, subject_product, and payload all verified aligned in the DB, yet
  the panel renders "No field value available" → "detail panel missing
  Non Applicable" (~11 specs: fsp5-*, my-data-onboarding-interactions,
  data-gathering-flow, supervisor subject-*). NARROWED via in-container
  Effect probes (recipe in `references/failure-triage-playbook.md`): the
  repository read path is healthy (decode → row found → mapper → Some);
  the failing panel also fetches `aggregate:address:<recordId>:proofDocument`
  child records that legitimately don't exist (no proof uploaded by wizard
  users) and the client breaks the WHOLE panel on that 404. App-side fix:
  don't advertise missing proofDocument child ids in the list, or tolerate
  404 on optional child records in the panel loader.
- React hydration error #418 on the cases hub kills client-side navigation:
  row clicks silently no-op (investigation I1 landed on the bare segment
  URL), toHaveURL waits expire. Needs a dev-mode repro for the unminified
  component stack (~9 specs: unassigned, investigation*, risk-factors-close,
  rationale-closing, admin/supervisor/requester/researcher pages).
- RU nationality: address step keeps Next disabled with complete data
  (screenshot-verified; no server-side errors) — ru-residency-permit,
  activity-band-evidence. This branch's own feature (GH-1405); the
  InfoRequest-materialization or wizard gating needs app triage.

RESOLVED this round (was listed as open in sweep 2): the seed-data cluster
(my-data/01-05, profile-settings — see fixture recipe above) and the
admin-cases page-object drift cluster (list-filters, deep-link,
hub-navigation, due-diligence — see Page-object drift above).

## Known pitfall: Logto mock setup restarts Logto on EVERY invocation

`ensure_logto_mock_email_connector` never consults its own
`.logto-mock-configured` marker — it reseeds the connector and restarts the
logto container on every e2e-serial.sh call (~1 min each). When driving many
single-spec invocations (grading sweeps), let only the first invocation run
the setup, then set `E2E_SKIP_LOGTO_MOCK_SETUP=1` for the rest. The sweep
script above does this automatically.

## Known pitfall: ANSI codes wrap Playwright error output

Playwright's console failure output embeds SGR escape codes around key
fragments — e.g. `\x1b[22m` sits directly between `- waiting for
getByTestId(...)` and ` to be visible`, so naive greps/regexes for `Error:` or
`waiting for` silently miss most failures. Always strip ANSI before extracting
signatures from raw logs: `re.sub(r'\x1b\[[0-9;]*m', '', text)` (Python) or
`sed 's/\x1b\[[0-9;]*m//g'`. Useful signature patterns after stripping:
`- waiting for <locator>` (locator-timeout class),
`My Data detail panel missing "<field>"` (shared-preamble assertion class),
`No verification code for <email> \((mock file\)` (env-wiring class).

## Technique: live-session network probe via a throwaway spec

When a failure is session-dependent and in-container probes can't reproduce it
(they have no auth session), capture the real HTTP traffic inside a temporary
e2e spec instead of trying to launch standalone Playwright scripts — chrome
won't launch outside the suite's runner (missing suite env), but the serial
runner works:

1. Write `tests/probe-net.spec.ts` copying a passing spec's preamble
   (beforeEach + page-object usage verbatim — inventing the wiring fails with
   layer/context errors), add `page.on('response', ...)` capture, `console.log`
   the lines, run via `bash bin/e2e-serial.sh tests/probe-net.spec.ts`, read
   the captured lines from the run log (strip ANSI), DELETE the spec after.
2. Gotcha: this app uses Next server actions — the detail panel's data fetches
   are POSTs to the page URL and return HTTP 200 even when the server action
   fails internally. Filtering by URL or status code shows nothing; capture
   response BODIES (`await r.text()`) and grep for error strings, and
   correlate with `docker logs test-nextjs` fibers (the TRACE lines carry
   `dataStructureId`/`subjectId` context for each server call).
3. Correlating which record id actually 404s matters: getShared TRACE lines
   are share-tab lookups (never 404 — they return []), while the NotFoundError
   fibers come from getMyDataRecord. Don't conflate the two when reading logs.
