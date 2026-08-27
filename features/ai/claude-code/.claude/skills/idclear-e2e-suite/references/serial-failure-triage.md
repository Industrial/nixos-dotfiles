# Serial-suite failure triage catalog

Snapshot: sweep 3, 2026-08-25 — 45 pass / 21 fail. These are APP-SIDE root
causes (verified against DB + server logs), not spec bugs. Re-verify before
acting; fixes land in app code and will invalidate entries here.

Sweep-2→3 delta (all test-side, each verified by a green single-spec run):
the compose test-nextjs image was STALE (missing commit 586867765) — rebuilt;
the supervisor identity fixtures were seeded (see the fixture recipe in
SKILL.md — my-data/01–05 + profile-settings now green); and the admin-cases
page-object drift cluster was fixed (list-filters, deep-link,
hub-navigation, due-diligence — see the Page-object drift section in
SKILL.md).

Post-sweep update (same day): the compose test-nextjs image was found STALE
(built ~6h before HEAD, missing commit 586867765). Rebuilt + restarted — the
pep-status 404 below PERSISTS on the fresh image, confirming it as a real app
bug (not an image artifact). Always check image freshness first:
`docker compose exec -T test-nextjs stat -c %Y /app/apps/test-nextjs/.next/BUILD_ID`
vs `git log --since=<that time> -- apps/test-nextjs libs`.

Test-side fixes that landed after sweep 2 (each verified by a green
single-spec run): list-filters (assignee filter lives on in-dd, options are
`<username> User`), deep-link DL2/DL4 (ng-client surface retired; search
context is the sidebar input, not `?search=`), hub-navigation L4/L6/L8/L10
(child tabs are routes; counters in sidebar links; `?assignedTo=` preset
breaks URL anchors), due-diligence D5 (case UUID in path, not `?id=`) plus
`clearAssigneeFilter` in `openCaseDetailById` (hub can land with
`?assignedTo=<self>` hiding seeded cases).

## 1. My Data detail panel 404 on pep-status records (~11 specs)

Symptom: `My Data detail panel missing "Non Applicable"` — the panel renders
"No field value available." (the old "missing Alias" failures were a stale
test expectation, fixed separately; this is what replaced them).

Evidence:
- test-nextjs logs `⨯ [NotFoundError]: Record not found` with
  `dataStructureId: 'dgr1:identity-profile:<gather-row-uuid>:identity-profile.pep-status'`.
- The gather row EXISTS:
  `select payload from identity_personal_details_gather where id='<uuid>'`
  returns `{"fields":{"identity-profile.pep-status":"non_applicable", ...}}`.
- Read paths to audit: `DataStructureDetailPanel` → `api.getMyDataRecord` →
  `getMyDataRecordProgram` → `DataGatheringApplicationService.getRecord` →
  `dataRepositoryFacade.getRecord` →
  `IdentityProfileRepositoryLive.getIdentityProfileRecord`
  (`valueForGatherField` / `mapGatherFieldToRecord`); fallback
  `api.getGatherDetail` → `getIdentityProfileProfileDataDetail`. One of the
  two 404s; the panel then has no projections and renders the empty state.

NARROWED (sweep-3 session, in-container probe): the repository read path is
HEALTHY. A bun probe inside temporal-worker (app source + real DB) proved
`decodeDataRecordId` → Right, `selectIdentityPersonalDetailsGatherById` finds
the row, `mapGatherFieldToRecord` produces a valid Scalar record with value
`non_applicable`. But the full `DataGatheringApplicationService.getRecord`
(via `ServerDataGatheringApplicationLayer` + `ServerAppLayer`) fails with
**`UnauthorizedDataOwner`** — which the API layer surfaces as the 404 the
panel sees. DB alignment is perfect (gather.owner_id =
subject_products.subject_id = eba58dd2), so the suspect is the session side:
`snap.activeProfileId` vs `subject_products.subject_id` for freshly-onboarded
wizard users. Nothing in the data-gathering/onboarding server code calls
`setActiveProfile` / `writeStoredActiveProfileId` (grep-verified); seeded
users have profile-id and subject-id synced by seeds, wizard users may not.
Next step needs a live authenticated session: dump `snap.activeProfileId` for
an onboarded user, compare with `subject_products.subject_id`, and check how
the my-data API maps UnauthorizedDataOwner to the 404.

Probe technique (temporal-worker has bun, app source, env): write a `.ts`
probe with STATIC imports of app modules (dynamic `await import()` namespaces
break — "undefined is not an object" on exported tags), `docker cp` it to
`/usr/src/app/apps/test-nextjs/`, run via `docker compose exec -T
temporal-worker sh -c '. /run/idclear-env/.env.development; cd
/usr/src/app/apps/test-nextjs; bun ./probe.ts'`, wrapping the program in
`withForkedRequestEntityManager(program).pipe(Effect.provide(<layer>))`.
Layer assembly is iterative — each "Service not found: X" names the next
layer to provide (`DataCatalogLive`, then
`ServerDataGatheringApplicationLayer`, `ServerAppLayer` for auth). Note an
anonymous probe fails authorization BY DESIGN — an `UnauthorizedDataOwner`
from a probe is only meaningful when you expected the data path to fail
instead (here it was: the repository layer was proven fine first).

Affected: fsp5-02, fsp5-06, fsp5-08, fsp5-10, my-data-onboarding-interactions,
data-gathering-flow, demo-supervisor, subject-rationale, subject-panel-tabs,
risk-calculation-ui.

## 2. demo.supervisor had no seeded My Data rows — RESOLVED (sweep 3)

Was: page rendered "No data items yet."; `ensureMyDataBddSeed` failed with
"BDD seed incomplete: no Name row on Active tab." Fixed by the fixture recipe
in SKILL.md (seed 0806 for the subject product + psql inserts for name /
nationality / gather rows, respecting the two id grains). my-data/01–05 and
profile-settings are green. If this regresses (e.g. volume reset), re-run the
recipe; note `subject_products.subject_id` is the platform subject id while
`subject_names.subject_id` is the internal `subjects.id`.

## 3. React hydration error #418 on admin cases list (~9 specs)

Symptom: "Minified React error #418" in the browser console; client-side
navigation dies — row clicks silently no-op (investigation I1 landed on the
bare segment URL with no caseId), `toHaveURL` waits expire. The page still
RENDERS (list, detail panes, filters all paint) — only JS-driven navigation
is dead, which makes it look like selector drift. Distinguish from drift by
checking whether ANY click navigates.

Notes:
- Needs a dev-mode repro (`E2E_START_NG_CLIENT=1` path, or `bun run dev`
  against the compose DBs) to get the unminified component stack; prod build
  only gives `args[]=text` (a text-node mismatch).
- Server logs separately show duplicate case-code errors from rule-engine
  StartCase (`cases_code_unique` violation on 901000000000131) — distinct
  issue, worth its own ticket.

Affected (sweep 3): unassigned, investigation,
investigation-techniques-full, risk-factors-close, rationale-closing,
admin-pages, demo-supervisor*, subject-rationale, subject-panel-tabs,
risk-calculation-ui, requester-pages, researcher-pages.

## 4. RU nationality: address step Next stays disabled (2 specs)

Symptom: with RU nationality and a fully-filled NL address (screenshot
verified: line1/line2/city/postcode populated, country Netherlands),
`nav-dg-step-next` never enables. No server errors — `SaveQuestionnaireDraft`
traces show drafts saving fine. Not caused by `needsResidencyPermit` (that
rule only emits an InfoRequest, priority 6; see
`libs/rule-engine/src/jdm/graphs/liveProductJdm.ts` and
`individualSubjectTables.ts`). Needs wizard-gating triage in the app.

The spec (ru-residency-permit) now fails fast with the active step title
instead of timing out on a locator; prohibited-nationality still hits the
generic 30s toContainText timeout.

## Triage recipes

- App data: `docker compose exec -T yb-pg psql -U postgres -p 5433 -d risk -tAc "<sql>"`.
  App data lives in db `risk` on yb-pg:5433 — the compose `DATABASE_URL` names
  a different db that does not exist on that server.
- Server errors: `docker compose logs test-nextjs --since 30m` and look around
  "Fiber terminated with an unhandled error"; `dataStructureId:` lines in the
  stack context identify the failing record id.
- Playwright logs embed ANSI SGR codes — strip `\x1b\[[0-9;]*m` before
  regexing.
- Page state at failure: `test-results/<slug>-chromium/error-context.md`
  (aria snapshot). Captured immediately after a failing run — the directory is
  wiped by the next invocation.
- Failure signatures per spec: split `/tmp/e2e-full-run.log` on
  `^===== \[\d+/66\] START (.+?) =====$` and extract the first `Error:` line
  per section (after ANSI-stripping).
