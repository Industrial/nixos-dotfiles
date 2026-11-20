# Prowlarr Declarative Config via Cursor-Pattern Symlinks — Plan

**Date:** 2026-08-23T094029Z
**Repo:** `/home/tom/.dotfiles`
**Ask:** Save prowlarr's configuration as a file under `features/media/prowlarr/` and symlink it into the right place on disk, following the `features/programming/cursor/` pattern.

## The Cursor Pattern (reference)

- Config files live in the feature dir mirroring their real on-disk layout:
  `features/programming/cursor/.config/Cursor/User/settings.json`
- A `bin/link-files-nixos` script symlinks them into `$HOME` (`ln -sf`), invoked from devenv shell hooks.
- Assumptions that hold for desktop apps: repo checkout exists on the machine, target is `$HOME`, app reads the file read-only.

## Fleet Reality for Prowlarr

- Prowlarr runs **natively on mimir** only (`hosts/mimir/configuration.nix:30`), service user `prowlarr`, `--data=/data/services/prowlarr`.
- Its hand-editable config is `/data/services/prowlarr/config.xml`. There is **no JSON server config**; arr apps store settings in `config.xml` + SQLite. JSON files exist only as indexer exports/backups.
- This workstation is **drakkar**; mimir:/data mounts at `/mnt/mimir` here. Live file confirmed at `/mnt/mimir/services/prowlarr/config.xml`.
- mimir has **no dotfiles checkout** (`~/dotfiles` missing) — a hard prerequisite of the cursor pattern.
- Existing precedent: `features/media/api-keys.nix` already declares secrets as data; `arr-wiring.nix` seeds them into config.xml idempotently.

## Proposed Design

1. **Repo-side source of truth:** `features/media/prowlarr/config/config.xml` — the declarative config, with `${apiKey}` placeholder resolved from `../api-keys.nix` at activation time (no secret committed to this file).
2. **Symlink:** `/data/services/prowlarr/config.xml -> <repo>/features/media/prowlarr/config/config.xml` on mimir, created by a NixOS module so it survives rebuilds and needs no manual step.
3. **Prereq:** clone the dotfiles to mimir at a stable path (proposed `/data/dotfiles`, NFS-exported, survives reformat). Without this, the cursor pattern cannot function for a native service.
4. **Safety rails:**
   - Activation script must never clobber an existing real file with different content without backup (`cp -a config.xml config.xml.bak.$(date)` before first link).
   - Prowlarr rewrites config.xml on UI changes → symlink makes drift visible immediately (file becomes "modified" in git terms on mimir only if repo is writable there; otherwise UI edits fail silently or get overwritten). Documented tradeoff: UI edits are transient by design.

## Execution Phases

1. **Phase 1:** Clone repo to mimir at `/data/dotfiles` (ssh tom@mimir, passwordless sudo available per operator-ssh).
2. **Phase 2:** Author `features/media/prowlarr/config/config.xml` (current live values, ApiKey templated from api-keys.nix).
3. **Phase 3:** Extend `features/media/prowlarr/default.nix` with an activation script: backup-if-differs → symlink into place → chown prowlarr:data.
4. **Phase 4:** Colocated assay suite asserting the symlink wiring + config shape (port 9696 present, ApiKey line exists, no literal secret).
5. **Phase 5:** Deploy to mimir via deploy-rs; verify symlink resolves and service restarts clean.

## Acceptance Criteria

- `readlink -f /data/services/prowlarr/config.xml` on mimir points inside `/data/dotfiles/features/media/prowlarr/config/`.
- Prowlarr healthy after deploy (systemd active, API responds).
- No *new* ApiKey material in the repo copy: config.xml's key must equal
  `api-keys.nix`'s prowlarr value (suite asserts equality with the imported
  data module; canonical secret home remains api-keys.nix).
