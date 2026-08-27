# Homarr: declarative board + sqlite reconciliation (mimir)

## Current architecture (landed Aug 2026, commits 64c185db → cad0d3e7 → 883cd85a)

Homarr runs as the **official OCI container** (`ghcr.io/homarr-labs/homarr:latest`,
port 7575) via `virtualisation.oci-containers` — NOT the vendored from-source
build. The from-source build (nixpkgs PR #430235 packaging, `pkgs/homarr/`) was
removed: its better-sqlite3 SIGABRTs under bundled Node 24
(`Statement::~Statement` → `node::RemoveEnvironmentCleanupHook` assert) on the
first tRPC requests, crash-looping the web unit. Do not reintroduce it.

Declarative config lives in `features/media/homarr/`:
- `board.json` — apps + integrations spec (Prowlarr wired with API key)
- `reconcile.js` — idempotent applier run INSIDE the container against
  `/appdata/db/db.sqlite`
- `export.js` — dumps live state back to JSON (secrets redacted to
  `SET-IN-api-keys-nix`)
- systemd units: `homarr-sync` (oneshot after container start, applies spec)
  and `homarr-export` (hourly timer + manual, writes UI changes back to the
  repo checkout at `/data/dotfiles`). Committing exported changes is manual.

Workflow: edit board.json → push → pull on mimir → deploy or restart
homarr-sync. UI edits flow back hourly via homarr-export; review + commit.

## Container DB schema facts (introspected live, homarr main image ~1.x)

- `app`: `(id,name,description,icon_url,href,ping_url)` — **no url column**;
  the link is `href`. `name` and `icon_url` are NOT NULL without defaults.
- `integration`: `(id,name,url,kind,app_id)` — url IS here.
- `integrationSecret`: `(kind,value,updated_at,integration_id)`, PK
  `(integration_id,kind)`.
- `item`: `(id,board_id,kind,options,advanced_options)`; app tiles carry
  options JSON `{json:{appId,...}}`.
- `board` INSERT requires many NOT NULLs without defaults
  (background_image_*, primary_color, secondary_color, opacity,
  disable_status, item_radius) — copy values from a healthy row.
- Ids are nanoid-style 24-char lowercase alphanumerics.
- Secret encryption: AES-256-CBC, key = hex-decoded SECRET_ENCRYPTION_KEY
  (must be exactly 64 hex chars), random 16-byte IV; stored as
  `<ciphertext-hex>.<iv-hex>`.

## Round-trip safety rules

- export.js never exports secret VALUES — only key names with placeholder
  `SET-IN-api-keys-nix`.
- reconcile.js skips re-seeding any secret whose declared value is a
  placeholder (`SET-IN-api-keys-nix` or `<...>`), so hourly export→sync can't
  clobber real encrypted secrets.
- Reconciler is add/update-only: it never deletes items missing from
  board.json (protects manual changes). Consequence: widget tiles (clock,
  weather) are recorded in exports but not yet re-created if the DB were
  rebuilt from scratch.

## Debugging pattern that worked

1. Copy a probe script into the container: `podman cp x.js homarr:/tmp/` then
   `podman exec homarr node /tmp/x.js` (container has its own node +
   better-sqlite3 at `/app/node_modules`; no sqlite3 CLI inside).
2. Introspect real schema before writing SQL:
   `db.prepare("PRAGMA table_info(t)").all()` and check `notnull`/`dflt_value`.
3. Capture the full SqliteError message ("NOT NULL constraint failed:
   table.column") — the journal only keeps the last lines.
4. Container /tmp is tmpfs: podman-copied files vanish on container restart;
   homarr-sync re-copies spec+scripts after every start by design.

## Operational notes

- Old native units (homarr-wss/tasks/migrate, redis-homarr, revive timer) are
  fully gone; don't reference them in assays or docs.
- homarr-wss historically needed SIGKILL on stop (TimeoutStopSec); irrelevant
  now but explains old journal noise.
- The pre-homarr dashboard was homepage-dashboard (nixpkgs module, port 8080,
  commit 48b635cc) — still the best-supported declarative option if homarr is
  ever abandoned again.
