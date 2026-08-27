# Declarative app-config round-trip: git-tracked spec ↔ live service state

Pattern for apps whose UI writes to a local DB/file and which must stay
reproducible from git. Worked cases: Prowlarr (config.xml symlink) and
Homarr (sqlite board) in the dotfiles repo, both on mimir.

> **Status 2026-08-24:** the Homarr instance was removed entirely (replaced
> by nixpkgs-native homepage-dashboard); this reference remains as the
> reusable pattern. Homarr-specific detail survives in
> `nixos-media-service-creation` → `references/homarr-board-sync.md`.
> Verified end-to-end while it ran: sync idempotent, export round-trip
> clean, UI deletions propagate on the next export run — the full lifecycle
> (add in UI → appears in board.json; remove in UI → disappears on next
> export) was confirmed live before removal.

## The three moving parts

1. **Git-tracked spec file** in the feature dir (`config/config.xml`,
   `board.json`). Single source of truth for what SHOULD exist.
2. **Sync path (spec → live):** a systemd oneshot `<app>-sync` that runs
   after the service unit. Two viable transports:
   - Symlink: repo file hard-linked into the data dir via activation
     script (Prowlarr). Works when the app reads a plain file at startup
     and rewrites it in place — make the repo copy group-writable so the
     service user's edits persist through the link.
   - In-container reconciler (Homarr): `podman cp` spec + script into the
     container, run against the internal sqlite with the app's OWN bundled
     driver (`/app/node_modules/better-sqlite3`). Use when state is a DB.
3. **Export path (live → spec):** a timer-driven oneshot (`<app>-export`)
   that dumps live state back into the repo spec **only when it differs**
   (`cmp -s`), then prints "review + commit". This is what satisfies
   "UI changes get saved to disk so we can git them".

## Rules learned the hard way

- **Idempotency is create-or-update, never delete**: reconcile only adds/
  updates declared entities; undeclared (manually added) items survive.
- **Never export secrets; never import placeholders.** Export writes a
  marker like `"SET-IN-api-keys-nix"` for secret values; the reconciler
  MUST skip any secret whose declared value equals the marker, or the
  hourly export→sync cycle silently clobbers real credentials.
- **Introspect the live schema before writing SQL** (`PRAGMA table_info`
  via the bundled driver). Assumed columns WILL be wrong: homarr's `app`
  has no `url` column (it's `href`) and NOT NULL no-default columns
  (`icon_url`) reject minimal INSERTs — provide defaults for every such
  column.
- **Encrypt secrets exactly as the app does.** Homarr: aes-256-cbc,
  key = hex-decoded SECRET_ENCRYPTION_KEY, random 16-byte IV, stored as
  `<ct-hex>.<iv-hex>`. Read the minified bundle to confirm format before
  writing rows by hand.
- **Container restarts wipe container-local /tmp**: sync units must copy
  spec+script in on every run; don't assume earlier `podman cp` survives.
- **The host checkout is part of the pipeline**: /data/dotfiles needs
  `git pull` (or deploy) before sync can see new specs; degrade gracefully
  ("skipping") when the checkout or spec file is missing.
- **Round-trip stability check**: run export twice and diff — if the
  second export differs from the first, the reconciler is still mutating
  state (e.g. bumping updated_at) and the timer will spam diffs forever.

## Manual export path (symlink apps, no export unit)

Prowlarr has NO `<app>-export` timer. Its "export" is implicit: UI edits are
written THROUGH the group-writable symlink straight into mimir's
/data/dotfiles clone, so the canonical workstation checkout drifts behind.
Pull-back procedure:

1. Detect: pipe the live file through ssh into a local diff —
   `ssh <host> "bash -c 'cat /data/services/prowlarr/config.xml'"` |
   `diff <repo>/features/media/prowlarr/config/config.xml -`.
   Secondary detector: `git status --short` in mimir's clone shows the spec
   file modified whenever UI edits have landed.
2. Replicate ONLY the changed values in the workstation copy (targeted
   patch, never a wholesale overwrite — unrelated drift may be in flight).
3. Commit with explicit pathspec, push.
4. Clear mimir's now-stale uncommitted mod (`git checkout -- <file>`)
   BEFORE its clone pulls again: post-push the contents are byte-identical
   to origin, so an uncleared pull aborts with "local changes would be
   overwritten".

Worked case 2026-08-24: prowlarr auth settings (AuthenticationMethod
None→Forms, AuthenticationRequired Enabled→DisabledForLocalAddresses)
pulled back and pushed as 7d4c2840.

## Verification shape

- Feature assay asserts module wiring (units declared, ports, volumes)
  AND parses the committed spec JSON/XML (keys present, expected names).
- Live checks: sync unit active, one clean reconcile log line per entity,
  idempotent re-run produces only "unchanged", HTTP probe of the port.
