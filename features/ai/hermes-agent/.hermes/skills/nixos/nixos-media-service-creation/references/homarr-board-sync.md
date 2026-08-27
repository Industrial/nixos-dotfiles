# Homarr declarative board sync (SQLite reconciler/export pattern)

Session record: 2026-08-24, mimir, homarr OCI container (`ghcr.io/homarr-labs/homarr:latest`).
Commits cad0d3e7 (pattern) + 883cd85a (schema fixes) — **pipeline fully green
as of 883cd85a**: sync idempotent, export round-trips clean, UI deletions
propagate on next export run.

> **STATUS: OBSOLETE 2026-08-24 (commit 8f501e36).** Homarr was removed from
> the fleet entirely and replaced by nixpkgs-native homepage-dashboard
> (port 8083 on mimir). The pattern below is kept as the reference recipe for
> ANY sqlite-persisted app whose UI writes rows instead of config files —
> declare state in a git-tracked JSON, reconcile on start, export hourly,
> redact secrets on export, skip placeholder values on re-import.

## RESOLVED: the third NOT NULL failure (was open)

`SqliteError: NOT NULL constraint failed: app.icon_url` — `app.icon_url` is
NOT NULL with no default. Fix in reconcile.js: default new apps to
`https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/<lowercase-name>.svg`
(overridable via `iconUrl` in board.json). Lesson: when the journal truncates
the error, re-run the script via podman exec and grep stderr for
`NOT NULL|SqliteError` to get the exact `<table>.<column>`.

Also fixed in 883cd85a:
- export.js selected phantom `app.url`; real link column is `href`.
- Round-trip secret safety: reconciler now SKIPS re-seeding secrets whose
  board.json value is a placeholder (`SET-IN-api-keys-nix` or `<...>`) —
  without this, hourly export→sync would clobber the real encrypted key
  with the placeholder.

## Container facts (verified live)

- App code at `/app`; data volume `/appdata` → host `/data/services/homarr/appdata`.
- Everything (boards, users, integrations) lives in `/appdata/db/db.sqlite`.
  No config files to symlink — this is why the prowlarr symlink pattern does
  not apply here.
- `entrypoint.sh` supports `_FILE` env-var suffixes and PUID/PGID; runs as
  root by default on podman.
- Node inside image: v24.18.0. `better-sqlite3` is at `/app/node_modules/better-sqlite3`
  — a reconcile script can `require()` it directly, no extra deps needed.

## DB schema notes (introspected via PRAGMA table_info)

- `app`: `id,name,description,icon_url,href,ping_url` — **no `url` column**;
  the tile's target is `href`. First INSERT attempt with `url` fails with
  `SqliteError: table app has no column named url`.
- `board`: many NOT NULL defaults required for INSERT:
  `background_image_attachment='fixed'`, `background_image_repeat='no-repeat'`,
  `background_image_size='cover'`, `primary_color`, `secondary_color`,
  `opacity`, `disable_status`, `item_radius`. Copy values from an existing
  board row (SELECT * LIMIT 1) rather than inventing them.
- `integration`: `id,name,url,kind,app_id`.
- `integrationSecret`: `kind,value,updated_at,integration_id`,
  PK `(integration_id, kind)` → upsert per secret kind.
- `item`: `id,board_id,kind,options,advanced_options`; app tiles are
  `kind='app'` with `options = {"json":{"appId":"<app.id>",...}}`.
  Position lives in `item_layout(item_id,section_id,layout_id,x_offset,y_offset,width,height)`.
- `section`/`layout`: one "Base" layout + one empty section per board is enough.
- Home-board pointer: `serverSetting` row `setting_key='board'`, value
  `{"json":{"homeBoardId":"<id>","mobileHomeBoardId":null,...}}`.

## Secret encryption (must match homarr exactly)

```js
const iv = crypto.randomBytes(16);
const c = crypto.createCipheriv("aes-256-cbc", Buffer.from(SECRET_ENCRYPTION_KEY, "hex"), iv);
const stored = `${Buffer.concat([c.update(pt), c.final()]).toString("hex")}.${iv.toString("hex")}`;
```

Key env: `SECRET_ENCRYPTION_KEY`, 64 hex chars (validated by homarr's zod
schema; also used by its own encrypt/decrypt chunk in the nextjs bundle).

## Reconciler shape (reconcile.js)

Idempotent upsert-only flow:
1. find-or-create board by name (INSERT with all NOT NULL defaults),
2. find-or-create layout "Base" + first section,
3. per integration: find-or-create row, then upsert each secret kind,
4. per app: find-or-create app row, then find-or-create tile item bound via
   `options LIKE '%"appId":"<id>"%'`, update x/y through item_layout,
5. set home-board pointer.
NEVER delete undeclared rows — manual UI additions must survive syncs.

## Sync/export units

- `homarr-sync` (oneshot, `after = ["homarr.service"]`, RemainAfterExit):
  install reconcile.js to /tmp on the HOST (so it comes from the deployed
  store), `podman cp` both files into the container, `podman exec node /tmp/reconcile.js /tmp/board.json`.
- `homarr-export` (`startAt = "hourly"`): `podman cp export.js`, run it,
  capture stdout, `cmp` against repo board.json, refresh only if different.
  Export redacts secrets: `"<kind>": "SET-IN-api-keys-nix"`.
- Graceful skip when `/data/dotfiles` clone or feature files are missing
  (same convention as prowlarr activation script).

## Assay coverage

Suite asserts: image/port/volumes/firewall shape, sync unit declared +
after-container + oneshot type, export timer hourly, and parses board.json
via `builtins.fromJSON (builtins.readFile ./board.json)` to pin the declared
integrations/apps. Note: `startAt` compares as the bare string `"hourly"`,
not a list.

## Verified end-state (883cd85a)

- Sync runs green and is idempotent (second run touches only secret
  timestamps); export produces spec-shaped JSON; UI deletions propagate on
  the next export run.
- Container restarts wipe /tmp inside the container (tmpfs) — homarr-sync
  re-copies spec+scripts after every start by design, so no manual cp needed.
- Remaining known gap: reconcile.js restores only `kind='app'` tiles;
  widget tiles (clock/weather) are exported as `{kind, options}` but not yet
  re-created from board.json if the DB were rebuilt from scratch.
