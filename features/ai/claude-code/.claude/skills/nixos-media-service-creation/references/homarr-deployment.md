# Homarr — native systemd deployment (OBSOLETE 2026-08-24, commit 8f501e36)

> **STATUS: REMOVED FROM FLEET.** Homarr is fully deleted from the repo
> (`features/media/homarr/` gone, overlay dropped, mimir import removed,
> commits 64c185db → cad0d3e7 → 8f501e36). It was replaced by the
> nixpkgs-native **homepage-dashboard** (`services.homepage-dashboard`,
> port 8083 on mimir) restored from git history — see SKILL.md section 9b
> for the replacement recipe and the port-collision pitfall (8080 now
> belongs to qbittorrent-nox). This reference survives as a worked example
> of: vendoring an unpackaged app from a closed nixpkgs PR, the Node 24 +
> better-sqlite3 SIGABRT landmine, rate-limit-aware restart design, and
> homarr-specific env/DB semantics (still relevant if homarr ever returns
> via its OCI image).

## Current architecture (features/media/homarr/default.nix)

Native systemd, NO Docker. Upstream ships no binaries — the package is
**vendored from closed nixpkgs PR #430235** ("homarr: init at 1.31.0") into
`pkgs/homarr/` (default.nix + 4 patches: local font instead of Google Fonts
fetch, variable WEB_PORT/WEBSOCKET_PORT envs, redis DB selection, nodejs
22.17 relax). The PR author abandoned upstreaming because Homarr refuses to
support bare metal; his hashes are the known-good starting point.

Exposed fleet-wide via overlay in `lib/mk-host.nix`:

    modules = [ ../hosts/${hostname}/configuration.nix
      {nixpkgs.overlays = [(final: prev: {homarr = final.callPackage ../pkgs/homarr {};})];} ];

Path is relative to `lib/` → `../pkgs/homarr`. callPackage needs a file named
`default.nix` inside `pkgs/homarr/`.

### Vendoring recipe (reusable for any unpackaged app)

1. `api.github.com/search/issues?q=repo:NixOS/nixpkgs+<app>+in:title` → find PR.
2. `curl https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/<n>.diff`
3. Extract each file's content (strip the outer diff wrapper: lines from
   `+++ b/...` onward, de-`+` prefixed). Keep ORIGINAL filenames — package.nix
   references patch files by name.
4. Expect drift vs current nixpkgs. Known migration: `fetcherVersion = 1`
   was removed in nixpkgs 26.11 → set `fetcherVersion = 3`, put a dummy hash,
   build `<pkg>.pnpmDeps`, take the `got:` sha256 from the mismatch error.
5. Build takes ~2-5 min (pnpm/turbo monorepo). Verify wrappers exist:
   `ls result/bin/` (homarr-migrate / nextjs / tasks / wss / shell).

## Runtime layout

## Unit topology (current)

- 4 units: `homarr.service` (web :7575), `homarr-wss` (:3001),
  `homarr-tasks` (cron), `homarr-migrate` (oneshot, RemainAfterExit).
  All User=homarr Group=data; Restart=always with **RestartSec=1200**
  (rate-limit budget — see below) except migrate oneshot.
- Coupling: web has `requires = ["homarr-migrate.service"]`; wss/tasks have
  `bindsTo = ["homarr.service"]` AND their own
  `wantedBy = ["multi-user.target"]` — bindsTo alone never STARTS a unit.

- Dedicated redis: `services.redis.servers.homarr` on **6380** loopback
  (6379 belongs to mimir's rootless container stack). The redis module sets
  `vm.overcommit_memory=1`; features/performance/memory pins 0 → homarr
  module must carry `lib.mkForce 1`.
- Env contract (from upstream Dockerfile + zod env schemas at v1.31.0):
  DB_URL=/data/services/homarr/appdata/db/db.sqlite, DB_DIALECT=sqlite,
  DB_DRIVER=better-sqlite3, REDIS_IS_EXTERNAL=true + HOST/PORT,
  AUTH_PROVIDERS=credentials, WEB_PORT=7575, WEBSOCKET_PORT=3001,
  SECRET_ENCRYPTION_KEY (64 hex), CRON_JOB_API_KEY (required in production;
  authenticates web<->tasks cron calls — missing it = every process fails
  "Invalid environment variables" with path ['CRON_JOB_API_KEY']),
  **AUTH_SECRET (64 hex; required by authjs in production — without it every
  tRPC request logs MissingSecret and the web app answers 500)**.
- All three keys are generated once and committed in the module (private repo).

## Config storage (unchanged by the rewrite)

Everything persists in `/data/services/homarr/appdata` (mounted as /appdata);
**the config IS `appdata/db/db.sqlite`** (boards/users/integrations/API keys).
Backup = copy that one file. Docs source:
github.com/homarr-labs/documentation docs/getting-started/installation/
docker.mdx on **master** branch (raw fetches on `main` 404).

DB schema quick-map (read-only inspection via better-sqlite3 from the
package's own node_modules, run as the homarr user): boards live in `board`,
home-board pointers in `serverSetting` (`setting_key='board'`, JSON value)
plus `user.home_board_id`; access grants in `boardUserPermission` /
`boardGroupPermission` (both empty = anonymous users can't resolve any
board). Inspect with a throwaway script scp'd to /tmp + chmod 644 —
sudo -u homarr node <script> — never sqlite3 (absent on hosts).

State-permission trap: a DB created by a root-run process stays root:root;
units then log `SqliteError: attempt to write a readonly database`. Repair =
one-time `chown -R homarr:data /data/services/homarr/appdata/db`, and then
restart ALL units — live processes hold prepared statements against the old
inode and native aborts surface at GC instead of clean errors.

## Verification (learned the hard way)

- `ui=500` + journal `MissingSecret`/`Please define a secret` → missing auth
  secret env. `Invalid environment variables ... path:['X']` → read the path
  element, add exactly that var. (AUTH_SECRET added 2026-08-23, commit 38c22740.)
- After deploy, confirm ALL FOUR units active (`bindsTo` units silently stay
  inactive if wantedBy is missing) and probe HTTP; redirects (307) and tRPC
  JSON `{"code":"NOT_FOUND"}` both mean the app answers.
- Env-only module changes do NOT restart the running unit — restructure the
  unit or restart explicitly, else you verify a stale process.
- Homepage tRPC board errors are POINTER problems, not corruption:
  `No home board found` = nothing points at a board;
  `Board not found` = a pointer exists but resolves wrong for that viewer.
  Fix by seeding `serverSetting.board` (JSON: `homeBoardId`,
  `mobileHomeBoardId`) AND `user.home_board_id`; if still failing for
  anonymous requests, seed `boardUserPermission`/`boardGroupPermission`
  rows — empty permission tables make boards unresolvable publicly.
- `homarr-wss` IGNORES SIGTERM: every stop ends `final-sigterm timed out` →
  SIGKILL → unit lands `failed` (Result: timeout) even though the app was
  healthy. Not an app fault; if it annoys deploys, tune
  `TimeoutStopSec`/`KillSignal` on the unit rather than debugging upstream.

## Known upstream landmine: Node 24 + better-sqlite3 (CONFIRMED fatal)

The vendored build ran on nodejs-slim 24.19.0. Under load, better-sqlite3's
statement finalizer aborts the whole process:

    Assertion failed: (env) != nullptr   (hooks.cc RemoveEnvironmentCleanupHook)
      Statement::~Statement() [better_sqlite3.node]  → SIGABRT, exit 1

Signature: web starts fine (`✓ Ready`), dies seconds after the FIRST tRPC
requests arrive; repeats on every restart; coredumpctl shows the same
`Statement::~Statement()` frames. NOT memory, NOT disk, NOT DB corruption
(rule those out with a read-only better-sqlite3 probe first). This was
ultimately confirmed as THE cause and forced the revert to the OCI image —
nodejs_22 pinning was never attempted because the OCI fallback is strictly
simpler. If native is ever retried: pin nodejs_22 in pkgs/homarr/default.nix
BEFORE anything else.

Diagnostic lesson worth keeping: after ANY repair that swaps or re-creates a
sqlite file under a live Node process (chown to fix permissions included),
prepared statements held against the old inode abort at GC time — always
restart all units of the app after touching its DB file, even for "just"
permission fixes.

## Rate-limit defence (added 2026-08-23, commit 38c22740)

homarr-tasks fetches icon repo trees from api.github.com on every start
(~3 requests/start; no GITHUB_TOKEN knob exists in tasks.cjs). When the
shared egress IP exhausts the anonymous 60 req/h quota, tasks aborts
(`Assertion failed: (env) != nullptr` + `Unable to request icons ... {}`)
and a 5s Restart loop burns ~2100 req/h — self-starving. Module now ships:
`RestartSec = 1200` (≈9 req/h worst case, leaves headroom for recovery) and
a `homarr-tasks-revive.timer` (OnCalendar=hourly, Persistent,
RandomizedDelaySec=5m, Unit=homarr-tasks.service) re-armed by
`ExecStartPost = "+systemctl start homarr-tasks-revive.timer"` so every
successful start re-arms it. Assay cases pin RestartSec==1200 and the timer.
Durable upstream fix would be a token env or graceful 403 degradation —
neither exists at v1.31.0.

## Assay suite (585-case repo suite includes these)

Stubbed import needs `pkgs = {homarr = "homarr";}` AND `lib = {}` (module now
uses lib.mkForce). Assert shape not values-with-paths: ExecStart interpolates
to "<store-path>/bin/homarr-wss", so use `builtins.match ".*/bin/homarr-wss"`
not string equality. Cases cover: systemPackages, unit descriptions,
User/Group/Restart, WEB_PORT "7575", sqlite DB_URL, REDIS_IS_EXTERNAL,
CRON_JOB_API_KEY present, **AUTH_SECRET present, RestartSec==1200,
homarr-tasks-revive timer declared + hourly**, wss/tasks ExecStart shapes,
requires=[migrate], tmpfiles /appdata rule, service user/group blocks.
