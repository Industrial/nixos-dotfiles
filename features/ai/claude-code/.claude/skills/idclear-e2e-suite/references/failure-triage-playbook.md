# e2e failure triage playbook (apps/e2e-test)

Condensed from the Aug 2026 full-sweep fix sessions (33 failing → 4 app-side clusters).
Class-level patterns; each was verified by a green single-spec re-run before committing.

## Triage recipe (per failing spec)

1. Re-run the single spec:
   `E2E_SKIP_LOGTO_MOCK_SETUP=1 devenv shell -- bash bin/e2e-serial.sh tests/<spec>.spec.ts > /tmp/run.log 2>&1`
   (background + notify_on_complete). Each run WIPES test-results/ — only the last run's
   artifacts survive, so re-run the spec you are triaging, not a batch.
2. Read `test-results/<slug>-chromium/error-context.md`: exact error + aria page snapshot
   (ground truth of what the page actually showed). `test-failed-1.png` complements it (view
   with vision — screenshots answer "what step/state was the page in" faster than DOM guessing).
3. Raw logs contain ANSI SGR codes — strip `\x1b\[[0-9;]*m` before grepping for
   'waiting for'/'Error:' lines, or your regexes silently match nothing.
4. Server-side truth: `docker compose logs test-nextjs --since 15m` (NotFoundError fibers,
   rule-engine evaluates). DB: `docker compose exec -T yb-pg psql -U postgres -p 5433 -d risk`.
   The container's DATABASE_URL host `yb-pg.idclear.localhost` does not resolve on the container
   network — for node/pg one-liners inside the container replace host with `yb-pg` and the db
   path with `/risk`.
5. Fix → re-run the single spec until green → `bunx tsc --noEmit -p tsconfig.json` (baseline
   has ~80 pre-existing errors; grep for YOUR files only) + `bunx biome check --write <files>`
   → commit `--no-verify` → batch re-verify the cluster.

## Recurring failure archetypes (app/e2e contract)

### Radix RadioGroup: never click `input[type="radio"]`
Radix renders the native input sr-only/`aria-hidden` inside a `<fieldset>` that intercepts
pointer events — `locator('input[type="radio"]:visible').click()` times out with
"fieldset intercepts pointer events". Click `getByRole('radio', { name })` (the Radix button)
or the option's `<label for>`. Hit PEP, Net Worth, and Expected Activity Level steps.

### Stale wizard DOM: visibility probes hit dead steps
The data-gathering wizard keeps prior steps mounted. `isVisible()` on a step-specific radio
returns true for steps that are no longer active — dispatch on the ACTIVE step heading
(`[data-testid="dg-step-title-default"]` textContent) instead of element visibility.
Walk-forward loops must ANSWER radio steps (Next stays disabled until an option is chosen):
PEP ('Non Applicable'), Net Worth ('€1 to €5,000'), etc.

### Page-object drift: snapshot-check → dead legacy fallback
Recurring shape: one `isVisible()` snapshot, then an unconditional
`waitFor(<legacy ng-client selector>)`. The snapshot races the mount, falls through, and the
legacy selector never appears → 30s timeout. Dead selectors seen: `.caseList span[title=…]`,
`.sidebar-wrapper .stateList`, `alt-select.expandable-sidebar-select`,
`#search-expandable-sidebar input`, `nav-case-tab-N`, `case-detail-back`, `#search=`/`?id=`
URL params. Fix with `waitFor(a.or(b).first())` disjunctions, or delete the legacy branch when
the surface is retired (the ng-client cases hub is gone — test-nextjs only).

### URL-pattern anchors break on query strings
`toHaveURL(/segment(\/|$)/)` fails when the app appends `?assignedTo=…`. Don't anchor; match
the path prefix. Current URL shape: `/admin/cases/<segment>/<caseUuid>?assignedTo=…&returnSegment=…&returnDdChild=…`
(legacy `?id=` is gone).

### Assignee-filter preset hides fixture cases
The hub can land with `?assignedTo=<self>` preset; seeded fixture cases belong to other users
→ "No cases in this queue" / row-wait timeouts. `clearAssigneeFilter` (AdminCasesListPage)
picks 'All users'; the UI keeps `?assignedTo=all` in the URL (doesn't drop the param — wait
for param==='all' or absent). Assignee options render as `<username> User` (e.g.
`demo.researcher1 User`) — filter by username, not display names. The filter is hidden on the
unassigned segment by design (casesHubFilterLayout) — exercise it on in-dd.

### Hidden nodes match text but report hidden
Mobile list-card variants (`lg:hidden` wrappers) contain the same text as desktop nodes;
getByText resolves them and toBeVisible times out ("unexpected value hidden"). Prefer
URL/testid assertions or scope away from the hidden wrapper.

## OPEN app-side bugs (Aug 2026, sweep 3: 45 pass / 21 fail — need app triage)

- **My Data detail 404**: `getMyDataRecord` 404s for
  `dgr1:identity-profile:<gatherRowId>:identity-profile.pep-status` although row, owner,
  subject_product (subject_id === owner), and payload all verify correct in the DB. Panel
  shows "No field value available." → 'detail panel missing "Non Applicable"' across ~11
  specs (fsp5-*, my-data-onboarding-interactions, data-gathering-flow, supervisor subject-*).

  **Narrowed via in-container probes (temporal-worker bun + SeedAppLayer):**
  - Repository read path is HEALTHY: decodeDataRecordId → Right, gather row found,
    mapGatherFieldToRecord → Some with correct value. Not the bug.
  - service.getRecord with an anonymous session fails `UnauthorizedDataOwner` (expected —
    no session); with the real session the failure surfaces as NotFoundError from
    getMyDataRecordProgram (the `Option.isNone` branch) — meaning repository.getRecord
    returned None at request time despite the row existing.
  - Server logs show the failing panel also requests
    `aggregate:address:<recordId>:proofDocument` (address rows with no uploaded proof —
    legitimately absent) and the client breaks the WHOLE panel on that 404.
  - Probe pattern: `docker compose exec temporal-worker` + source
    `/run/idclear-env/.env.development` + `cd /usr/src/app/apps/test-nextjs` + bun script
    with `withForkedRequestEntityManager(program).pipe(Effect.provide(SeedAppLayer))`.
  - Next step for app triage: dev-mode repro of the detail panel with a fresh wizard user;
    check whether the list advertises `aggregate:address:<id>:proofDocument` for addresses
    with no proof (list/reader contract mismatch) and whether the panel should tolerate
    404 on optional child records instead of failing the whole panel.
- **RU nationality: address step Next stays disabled** with complete non-RU address
  (screenshot-verified; no server-side errors; drafts save fine). Blocks
  ru-residency-permit + activity-band-evidence (GH-1405 area). The spec now fails fast
  naming the step instead of timing out.
- **React #418 hydration failure on the cases hub** (text mismatch): kills client-side
  navigation — row clicks silently no-op, client redirects never fire. ~9 specs
  (unassigned, investigation*, risk-factors-close, rationale-closing, admin/supervisor/
  requester/researcher pages). Needs a dev-mode repro (`bun run dev`, non-minified error)
  to find the mismatching text node. Suspects: queue counters or date rendering.

## RESOLVED this round (was open in sweep 2 — do not re-triage from scratch)

- **demo.supervisor seed gap**: FIXED via fixture repair (seed 0806 + name/nationality/
  gather-row inserts — recipe in SKILL.md). my-data/01–05 green.
- **profile-settings**: `profile-info-email` testid retired → `field-email` (AggregateFieldList
  → InputField wrapper; the `<input>` is inside the wrapper). Form requires lastName + phone
  (phoneCallingCode + phoneNationalNumber) — seeded product-test users have a UUID as name,
  empty last name, no phone → Save permanently disabled. `fillRequiredFieldsIfEmpty` in
  UserProfilePage fills only-when-empty: lastName, phone number (testid
  `profile-info-phone-number` is ON the `<input>`, not a wrapper), and country code via the
  `profile-info-phone-country` combobox (+31). Green 4 passed.
- **Admin cases page objects**: list-filters / deep-link / hub-navigation / due-diligence all
  green — see the drift archetypes above for the applied fixes.

## Effect/e2e code gotchas

- `Effect.promise(() => someEffect)` — wrapping an Effect in Effect.promise →
  "TypeError: evaluate(...).then is not a function". `yield*` the Effect directly.
- `await` inside `Effect.gen(function* () {…})` doesn't compile — use
  `yield* Effect.promise(...)` or `Effect.tryPromise({ try: async () => …, catch: … })`.
- `Effect.tryPromise` requires a catch clause; `catch: () => fallback as never` swallows real
  errors — use sparingly and only for best-effort probes.

## Sweep annotation convention

`DEFAULT_E2E_SERIAL_SPECS` lines: `#` = passed, `##` = failed/to-retry, bare = active.
After a sweep, rewrite the lines from the results TSV (rc != 0 → `##`), `bash -n` the script,
and confirm `git diff --stat` shows exactly the spec lines changed.
