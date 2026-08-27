# Template: cursor-pattern declarative config wiring for an arr-style native service
#
# Copy into features/media/<svc>/default.nix with these substitutions:
#   <svc> -> service name lowercase (sonarr/radarr/lidarr/readarr/prowlarr/...)
#   <Svc> -> human name for comments/warnings  (Sonarr/Radarr/Lidarr/...)
# Three pieces: (A) let-bindings, (B) activation script, (C) assay additions.
# Full recipe: references/declarative-config-symlink.md
# Proven on all five arr services (commit 2c44287e, 2026-08-24).

## (A) let-bindings — insert after `directoryPath = "/data/services/${name}";`

```nix
  # Cursor-pattern declarative config: the file lives in the dotfiles repo
  # (cloned at /data/dotfiles on mimir) and is symlinked into the service's
  # data dir. <Svc> rewrites config.xml on UI changes, so the repo file is
  # made group-writable for the service's 'data' group — owner-side git
  # access is preserved.
  dotfilesRepo = "/data/dotfiles";
  configSource = "${dotfilesRepo}/features/media/<svc>/config/config.xml";
```

## (B) activation script — insert between the `systemd` block and `users`

Patch-anchor warning: `users = {` appears TWICE in these modules (top-level
and nested) — anchor edits on the tmpfiles rule
`"d ${directoryPath}/data 0770 ${name} data - -"` instead.

```nix
  # Link the declarative config into the service data dir (idempotent).
  # A pre-existing real file is backed up once before the first link takes
  # over; a missing repo checkout degrades gracefully to the live file.
  system.activationScripts.<svc>Config = {
    text = ''
      source="${configSource}"
      target="${directoryPath}/config.xml"
      if [ ! -f "$source" ]; then
        echo "<svc>: $source missing (is ${dotfilesRepo} cloned?); keeping existing config" >&2
      else
        mkdir -p "$(dirname "$target")"
        if [ -f "$target" ] && [ ! -L "$target" ]; then
          if ! ${pkgs.diffutils}/bin/cmp -s "$target" "$source"; then
            cp -a "$target" "$target.bak.$(date +%Y%m%d%H%M%S)"
          fi
        fi
        ln -sfn "$source" "$target"
        chgrp data "$source" 2>/dev/null || true
        chmod 0664 "$source"
      fi
    '';
  };
```

Bash spacing matters: `[ ! -L "$target" ]` — a missing space before `]`
(`"$target"]`) passes every Nix-level check and only fails at activation time.

## (C) colocated assay — start from features/media/prowlarr/default.assay.nix

Rename the suite and every attribute to `<svc>`, set the expected port, and
set `declaredKey = (import ../api-keys.nix).<svc>;`. The stub pkgs MUST
include `diffutils = "/bin/cmp";` alongside `<svc> = "<svc>";` (the module's
`${pkgs.diffutils}` reference otherwise breaks eval). Asserted properties:
activation attr declared, /data/dotfiles path embedded in script text,
`ln -sfn` present, backup guard present, degradation message present, port
in source, ApiKey parity vs api-keys.nix (compared, never emitted).

## Also required

Create `features/media/<svc>/config/config.xml` seeded from the LIVE file on
the serving host. Its ApiKey must already equal the api-keys.nix value —
verify before committing (parity is an assay assertion, and a mismatch would
commit un-reviewed secret drift).

Gate order: nix-instantiate --eval each assay → `nix flake check` →
`devenv shell -- assay run .` → pathspec-limited commit → push → sync the
host clone at /data/dotfiles → deploy → verify symlinks/units/single-.bak.
