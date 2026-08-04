# nixstore

Read-only Nix store **path-info** over `db.sqlite` (tier 3 of the Nix→Rust ladder).

**Doctrine:** query `ValidPaths` / `Refs`; never shell out to `nix`; never write the DB.

## Library

- `open_db` / `SqlitePathInfoStore` — SQLite URI `mode=ro`
- `PathInfo` — v1-shaped JSON fields (`narHash` SRI, full paths, `references`)
- `PathInfoStore` cap + `MockPathInfoStore` for assay / unit tests
- Closure size via BFS over references

Assay (`pathInfo` claim) and nixq (`path-info` subcommand) depend on this crate.

**Dependency rule:** no `nixq` / `nixdrv` deps (avoids workspace cycle: `nixdrv` → `nixq` → `nixstore`).

## CLI

```bash
nixstore path-info [--json] [-s|--size] [-S|--closure-size] [-h|--human-readable] \
  [--sigs] [--referrers] [--store DIR] PATH...
```

Default DB: `{store}/var/nix/db/db.sqlite` with `store` defaulting to `/nix`.

## Packaging (v1)

Devenv + moon only (`cargo test -p nixstore`). No NixOS module yet.

## Non-goals

- GC delete / roots planner
- Daemon / remote store protocol
- NAR walk / hash from filesystem
- `--all` full-store dump
- JSON format v2/v3
