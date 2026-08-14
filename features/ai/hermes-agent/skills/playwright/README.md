# Playwright skills for Cursor

Curated Playwright agent skills under `.cursor/skills/playwright/`. Cursor discovers nested `SKILL.md` folders recursively.

**12 discoverable skills** + reference packs (~2.5MB) from TestDino, fugazi, and Qualiow.

## Quick pick

| Task | Skill |
|------|-------|
| Comprehensive guides (70+ topics) | `playwright-skill` (+ `core/`, `ci/`, `pom/`, …) |
| E2E test authoring | `playwright-e2e-testing` |
| Regression / CI suites | `playwright-regression-testing` |
| Web app flows | `webapp-playwright-testing` |
| Accessibility | `a11y-playwright-testing` |
| CLI browser automation | `playwright-cli`, `playwright-skill/playwright-cli`, `qualiow-skills/playwright-cli` |
| Page Object Model | `playwright-skill/pom` |
| Cypress/Selenium migration | `playwright-skill/migration` |

## Catalog

### TestDino — `playwright-skill` ([testdino-hq/playwright-skill](https://github.com/testdino-hq/playwright-skill))

Root skill + sub-packs (each has its own `SKILL.md`):

| Pack | Guides | Topics |
|------|--------|--------|
| **core/** | 46 | Locators, assertions, fixtures, auth, API, mocking, a11y, debugging, framework recipes (Next.js, Angular, …) |
| **ci/** | 9 | GitHub Actions, sharding, Docker, reporting |
| **pom/** | 2 | Page Object Model patterns |
| **migration/** | 2 | From Cypress, from Selenium |
| **playwright-cli/** | 11 | CLI automation, tracing, sessions |

Markdown reference files live beside each pack (e.g. `core/locators.md`).

### fugazi — [fugazi/test-automation-skills-agents](https://github.com/fugazi/test-automation-skills-agents)

- `playwright-e2e-testing`
- `playwright-regression-testing`
- `webapp-playwright-testing`
- `a11y-playwright-testing`
- `playwright-cli`

### Qualiow — [willcoliveira/qualiow-playwright-skills](https://github.com/willcoliveira/qualiow-playwright-skills)

Reference library (not all folders are standalone skills):

- **`qualiow-skills/playwright-cli/`** — SKILL.md + CLI reference docs
- **`qualiow-skills/core/`** — patterns, test review, data strategy (markdown)
- **`qualiow-templates/`**, **`qualiow-indexes/`** — templates and IDE index files

## Repo context

- **Primary E2E app:** `apps/e2e-test/` — Playwright **1.52** (nix/devenv aligned)
- **Also:** `apps/test-nextjs` may pin a newer Playwright for its own tests
- Page objects: `apps/e2e-test/pages/`, auth/Logto: `LogtoRegisterPage.ts`, `tests/support/authSession.ts`
- Config: `apps/e2e-test/playwright.config.ts`
- Run via devenv: `devenv shell --` wraps test commands

Prefer **`playwright-skill/core/authentication.md`** and repo **`idclear-logto-monorepo`** when testing Logto flows.

## Sources & licenses

| Source | Skills | License |
|--------|--------|---------|
| [testdino-hq/playwright-skill](https://github.com/testdino-hq/playwright-skill) | 6 SKILL.md (root + 5 packs) | MIT |
| [fugazi/test-automation-skills-agents](https://github.com/fugazi/test-automation-skills-agents) | 5 | See upstream |
| [willcoliveira/qualiow-playwright-skills](https://github.com/willcoliveira/qualiow-playwright-skills) | 1 + references | See upstream |

## Updating

```bash
TMP=$(mktemp -d)

# TestDino (full tree)
git clone --depth 1 https://github.com/testdino-hq/playwright-skill.git "$TMP/playwright-skill"
rm -rf .cursor/skills/playwright/playwright-skill
cp -a "$TMP/playwright-skill" .cursor/skills/playwright/playwright-skill

# fugazi (5 skills)
git clone --depth 1 https://github.com/fugazi/test-automation-skills-agents.git "$TMP/fugazi"
for s in playwright-e2e-testing playwright-regression-testing webapp-playwright-testing a11y-playwright-testing playwright-cli; do
  rm -rf ".cursor/skills/playwright/$s"
  cp -a "$TMP/fugazi/skills/$s" ".cursor/skills/playwright/$s"
done

# Qualiow references
git clone --depth 1 https://github.com/willcoliveira/qualiow-playwright-skills.git "$TMP/qualiow"
rm -rf .cursor/skills/playwright/qualiow-skills .cursor/skills/playwright/qualiow-templates .cursor/skills/playwright/qualiow-indexes
cp -a "$TMP/qualiow/skills" .cursor/skills/playwright/qualiow-skills
cp -a "$TMP/qualiow/templates" .cursor/skills/playwright/qualiow-templates 2>/dev/null || true
cp -a "$TMP/qualiow/indexes" .cursor/skills/playwright/qualiow-indexes 2>/dev/null || true

find .cursor/skills/playwright -name "SKILL.MD" | while read -r f; do mv "$f" "$(dirname "$f")/SKILL.md"; done
find .cursor/skills/playwright -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
```

Official installer (alternative): `npx skills add testdino-hq/playwright-skill`
