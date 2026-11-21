# vdiff

The package-level diff of two Nix closures: what `nvd diff` prints, read
straight from the store database. It replaces nvd in the update and deploy
flow (GH-153). Written in Voltaic 0.2.1 (`src/*.vlt`, compiled by `build.rs`)
with id_effect 0.13.0; the store primitives are nix-store-core's.

```
vdiff [--json] [--db PATH] <old> <new>
vdiff [--json] [--db PATH] --generations <profile>
```

- `<old>` and `<new>` are store paths, or anything that links into the store:
  `/run/current-system`, `/nix/var/nix/profiles/system-492-link`, a `result`.
- `--generations system` diffs the newest two generations of
  `/nix/var/nix/profiles/system`. A profile with a `/` in it is a path
  (`--generations ~/.local/state/nix/profiles/home-manager`). A profile with
  fewer than two generations is an error.
- `--db` reads another store database (default `/nix/var/nix/db/db.sqlite`,
  opened read-only: no daemon, no root).
- Exit codes are id_effect_cli's: 0, 1 on any error (usage, a missing path, a
  path that is not valid, an unreadable database), 101 on a bug, 130 on Ctrl-C.

The two closure walks run concurrently, as two id_effect fibers (`zip_par`),
each on its own read-only connection.

## In the fleet: vdiff took over from nvd

- `features.cli.vdiff` is on in `profiles/cli-core.nix`, so every host with
  that profile has `vdiff` on its PATH. `features.cli.nvd` is off.
- Callers: `bin/dev build <this host>` diffs the fresh closure against
  `/run/current-system` with vdiff. Nothing else in the repo called nvd.
- `nh` (4.5) prints its own diff with its built-in differ (dix). It has no
  option to run an external one: `--diff` only takes
  `auto|always|never|full`. Use `nh os switch --diff never` and
  `vdiff --generations system` afterwards to get vdiff's report.
- `nixos-update-notifier` diffs with `nix store diff-closures`, Nix's own
  differ, not nvd's. It is left as it is.
- Rollback: `features.cli.nvd.enable = true;` on a host installs nvd again
  (the `nvdIsTheRollback` assay claim in `profiles/cli-core.assay.nix`).
  `bin/dev build` uses nvd only where vdiff is missing, so a host that also
  sets `features.cli.vdiff.enable = lib.mkForce false;` is fully back on nvd.

## The text

The default output is `nvd --color=never diff`'s, byte for byte: the golden
tests check it against nvd 0.2.4's own output. What it reports, and how:

- A store path `<hash>-<name>` is split as nvd splits it: the package name is
  the shortest prefix followed by `-<digit>`, and the rest is the version, so
  output suffixes stay in it (`openssl-3.0.13-bin` is `openssl`, version
  `3.0.13-bin`). A name with no such dash has no version (`<none>`).
- A closure is grouped by package name; a name's versions are those of all its
  paths, sorted by nvd's order (runs of digits and letters; numbers as
  numbers, words before numbers, `pre` before other words; a longer version
  wins a tie, so `1.0pre1` is newer than `1.0`, as in nvd and unlike `nix-env`).
- **Version changes**: a name in both closures whose version lists differ.
  `U` when the old newest is older than the new oldest, `D` the other way, `C`
  otherwise. New hashes with the same versions are not a change.
- **Selection state changes**: same versions, but a direct dependency
  ("selected") on one side only. Selected means a direct reference of the
  system's `sw` when both sides have one, else of the root.
- **Added** / **Removed** packages: a name on one side only.
- The second status character is the selection state: `*` selected on both
  sides, `.` on neither, `+` newly selected, `-` no longer selected.
- **Closure size**: path counts, paths added and removed, and the change in the
  sum of narSize (nvd's `nix path-info --closure-size` disk usage).

Deliberate differences from nvd: no colour (nvd's `--color=always`), no
`--sort`, `--selected`, `list` or `history`. Versions that compare equal but
are spelled differently (`1.0` and `1-0`) show the spelling of the path that
sorts last in the store's byte order, where nvd shows the one `nix-store -qR`
lists last.

## `--json` (schema 1)

For vdeploy (#159). Stable: a change a reader could notice bumps `schema`.

```json
{
  "schema": 1,
  "old": { "label": "/nix/var/nix/profiles/system-492-link", "path": "/nix/store/…-nixos-system-…", "paths": 3544, "narSize": 15032385536 },
  "new": { "label": "…", "path": "/nix/store/…", "paths": 3626, "narSize": 18682085376 },
  "changed": [
    { "name": "hello", "kind": "upgraded", "selection": "*", "old": ["2.12.1"], "new": ["2.12.2"] }
  ],
  "selectionChanged": [
    { "name": "jq", "kind": "changed", "selection": "+", "old": ["1.7.1"], "new": ["1.7.1"] }
  ],
  "added":   [ { "name": "fresh", "kind": "added", "selection": "+", "old": [], "new": ["1.0"] } ],
  "removed": [ { "name": "gone", "kind": "removed", "selection": "-", "old": ["2.0"], "new": [] } ],
  "closure": { "pathsAdded": 3597, "pathsRemoved": 3515, "narSizeDelta": 3649699840 }
}
```

- `label` is the argument as given (normalised like nvd's `<<<`/`>>>` lines);
  `path` is the store path it resolved to; `paths` counts the closure's paths;
  `narSize` is their total NAR size in bytes.
- Every list is sorted by `name` (byte order). `kind` is `upgraded`,
  `downgraded` or `changed` in `changed`; `changed` in `selectionChanged`;
  `added` / `removed` in those lists.
- `old` / `new` are the versions on each side, one per store path, oldest
  first, `""` for a path with no version; empty on the side a package is not on.
- `selection` is the selection state as in the text (`*`, `.`, `+`, `-`).
- `narSizeDelta` is `new.narSize - old.narSize`, signed.

## Tests

`cargo test` runs:

- `version`: name and version splitting and the version order, over nvd's
  tricky cases (output suffixes, digits in names, a one-character name,
  `.drv`, leading zeros, `pre`, numbers longer than any integer type).
- `report`: the diff, `render_bytes`, the text layout and the JSON.
- `golden`: `tests/fixtures/*.json`, closures with nvd's output for them; the
  text must match exactly. `synthetic.json` is nvd's tricky cases run through
  nvd's own code (`tests/nvd-synthetic.py`, no store needed); `drakkar-*.json`
  is a real pair of drakkar's system generations (`tests/gen-fixture.sh <old>
  <new> <out>`, with `nix`, `nvd` and `jq`).
- `closure` and `app`: argument handling, generation links, path resolution,
  and a real walk of `/run/current-system` where there is one.

`default.nix` packages the crate as its own test run.
