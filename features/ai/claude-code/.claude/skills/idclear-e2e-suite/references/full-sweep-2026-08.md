# Full-sweep snapshot — 2026-08-24/25

## Sweep 3 (final, after fixture + page-object rounds): 45 passed / 21 failed

Commits landed between sweep 2 and sweep 3 (all verified green individually
before the sweep):

- Fixture repair: seed 0806 (subject products for demo.admin/supervisor via
  temporal-worker + `withForkedRequestEntityManager`) + direct psql inserts of
  supervisor identity rows (name / nationality / gather row with pep-status +
  DOB). → my-data/01–05 green (9/4/5/5/1 passed). ID-grain notes and the
  exact recipe: SKILL.md "Fixture repair" section.
- `dd6b21942` — profile-settings green (4 passed): `field-email` testid
  (old `profile-info-email` retired), `fillRequiredFieldsIfEmpty` fills
  empty lastName/phone/country-code so Save enables.
- `0252a6cac` — list-filters green (2 passed): assignee filter lives on in-dd
  only; filter by `demo.researcher1` (options render `<username> User`).
- `113340d5a` — deep-link green (4 passed): DL2 no-op (ng-client retired),
  DL4 asserts the sidebar search input value instead of `?search=`.
- `9ae54e4c6` — hub-navigation green (9 passed): L4 routes instead of dead
  pills, L10 sidebar-link counters, L6/L8 drop `(/|$)` URL anchors (preset
  `?assignedTo=` follows the segment).
- `a3e90beb8` — due-diligence green (5 passed): `clearAssigneeFilter` in the
  shared list-mode open path (preset `?assignedTo=<self>` hid fixture rows);
  D5 asserts the UUID path; openTab inserts the tab segment when the URL has
  no child to swap.
- Also: rebuilt the stale test-nextjs image (was 6h behind HEAD, missing
  `586867765`) — pep-status 404 persisted on the fresh image, confirming it's
  real.

Sweep-3 failures: 21, three app-side root causes (current catalog with
verification recipes: `references/failure-triage-playbook.md` "OPEN" section):

1. My Data detail 404 on `identity-profile.pep-status` (~11 specs) — row,
   owner, subject_product, payload all verified aligned; read path still
   returns NotFound. Needs dev-mode debugging.
2. React #418 hydration failure on the cases hub (~9 specs) — client
   navigation dead; needs dev-mode repro for the unminified stack.
3. RU nationality address-step gate (~2 specs) — Next disabled with complete
   data.

---

## Sweep 2 (post-first-fix round, 2026-08-24): 34 passed / 32 failed

Between sweeps, three commits landed on
`bugfix/ob-rus-address-residency-permit`:

- `34ff7a3b7` — volturapay-embed-full-onboarding fixed (PEP label mismatch,
  see SKILL.md resolved pitfall). Now green.
- `93fa4a9e1` — stale `wizardMyDataDetailExpectations` corrected (asserted
  "Alias"/secondary data the wizard never writes → primary-only data), and
  ru-residency-permit flow corrections (clickPrevious before switching
  nationality; walk-forward loop answers PEP/Net Worth by active step
  heading). The "missing Alias" signature is gone from sweep 2.
- Serial-script annotation updated; HEAD matches sweep-2 truth.

Sweep-2 failures collapse into 4 app-side root causes (DB + server-log
verified) — full catalog with triage recipes:
`references/serial-failure-triage.md`.

1. My Data detail 404 on `identity-profile.pep-status` records
   (`NotFoundError dgr1:identity-profile:<row>:identity-profile.pep-status`;
   row exists with the value in `identity_personal_details_gather`) →
   panel renders "No field value available." → ~10 specs.
2. `demo.supervisor` has zero seeded My Data rows under compose
   (`E2E_SKIP_DB_SEED=1`) → "No data items yet." → my-data/01–05,
   profile-settings.
3. React hydration error #418 on the admin cases list → click/nav timeouts →
   ~12 admin/supervisor/portal specs (hub-navigation passes 8/9, so not
   fixtures).
4. RU nationality: address step keeps `nav-dg-step-next` disabled with
   complete data (screenshot-verified; no server errors) →
   ru-residency-permit, prohibited-nationality.

---

## Sweep 1 (first recorded grading sweep)

All 66 `DEFAULT_E2E_SERIAL_SPECS` entries run one-by-one through
`bin/e2e-serial.sh` (fail-safe driver, now `scripts/sweep-all-specs.sh`).
Context: branch `bugfix/ob-rus-address-residency-permit`, compose stack fully
healthy (all services Up 4h), docker-compose mode flags as exported by the
script.

Outcome: **33 passed, 33 failed**; annotations applied to
`apps/e2e-test/bin/e2e-serial.sh` (`#`/`##` prefixes).

### Failure clusters (33 red)

1. **My Data detail panel missing "Alias"** ×10 — shared onboarding preamble
   times out (15 s, `expect(locator).toContainText`) looking for "Alias".
   Specs: `individual/fsp5-02-sharing-transparency`,
   `individual/fsp5-06-data-amendment-request`, `fsp5/fsp5-08-data-propagation`,
   `fsp5/fsp5-10-data-status-indicators`,
   `individual/my-data-onboarding-interactions`,
   `individual/data-gathering-flow`, `supervisor/demo-supervisor`,
   `supervisor/subject-rationale`, `supervisor/subject-panel-tabs`,
   `supervisor/risk-calculation-ui`.
   Signature: `Error: My Data detail panel missing "Alias": Error: Timed out 15000ms…`
2. **My Data list never renders** ×5 — `tests/individual/my-data/01..05` all
   time out on `getByTestId('my-data-items')`.
3. **admin/cases click & navigation timeouts** ×10 — hub-navigation,
   list-filters (click 5000 ms), unassigned (heading `/Access and Assign/`),
   due-diligence + investigation (`.caseList span[title="901000000000002"]`),
   investigation-techniques-full, risk-factors-close, rationale-closing,
   lifecycle-chain (click 30000 ms), deep-link (`toHaveURL` 30000 ms).
4. **Portal headings/nav missing** ×4 — `admin/admin-pages`,
   `supervisor/demo-supervisor-nav-pages`, `requester/requester-pages`
   (heading `/Subjects Product Subscriptions List/`);
   `researcher/researcher-pages` (`getByTestId('nav-header-admin-cases')`).
5. **rule-engine onboarding-guards** ×2 — ru-residency-permit +
   prohibited-nationality: `field-countryCode` combobox / assertion timeouts.
   These sit in this branch's own subject area (GH-1405/GH-1409 work).
6. **individual/profile-settings** ×1 — `getByTestId('profile-info-email')`
   never becomes visible.
7. **unauthenticated/volturapay-embed-full-onboarding** ×1 — misdiagnosed at
   the time as the env-wiring pitfall; real cause was the PEP label mismatch
   (fixed, see SKILL.md).

Reading: clusters 1–2 share one preamble/list symptom across unrelated suites
→ shared fixture/app-state breakage, not 33 independent bugs. Sweep 2
confirmed: cluster 1 split into a stale test expectation (fixed) + an app-side
record-404 root cause (open).

## Artifacts from those runs

- Raw log + exit codes were at `/tmp/e2e-full-run.log` and
  `/tmp/e2e-serial-results.tsv` (ephemeral — regenerate via the sweep script;
  persistent outputs land in `apps/e2e-test/.e2e-sweep/`).
- Per-spec traces/videos/screenshots:
  `apps/e2e-test/test-results/<spec-slug>-chromium/{trace.zip,video.webm,test-failed-N.png,error-context.md}`.
  `test-results/` is wiped by every subsequent playwright invocation — only
  the last failing run's artifacts survive.
- Annotation diff: `apps/e2e-test/bin/e2e-serial.sh` (66 relabelled lines).

