# World of Warcraft Configuration

This feature module tracks World of Warcraft settings (`WTF/`) and AddOns
(`Interface/`) in this repository and symlinks them into the Wine prefix, so the
game reads and writes straight into your dotfiles.

## Directory Structure

```
features/games/wow-classic/
├── default.nix          # NixOS module (installs the link-wow-classic command)
├── default.assay.nix    # Tests
├── bin/link-wow-classic # The linker
├── WTF/                 # Settings, keybinds, macros, saved variables
└── Interface/
    └── AddOns/          # Individual addon directories
        ├── idAutomation       # git submodule (Industrial/idAutomation)
        └── idAutomation_Bench # symlink -> idAutomation/bench/idAutomation_Bench
```

## How It Works

`link-wow-classic` replaces the game's `WTF` and `Interface` directories with
symlinks pointing back into this repo:

```
<flavor>/WTF       -> ~/.dotfiles/features/games/wow-classic/WTF
<flavor>/Interface -> ~/.dotfiles/features/games/wow-classic/Interface
```

Because these are plain out-of-store symlinks, the game can write to them and
changes show up immediately as working-tree changes here. No rebuild is needed
for content changes — only for edits to `default.nix`.

### Flavor directory detection

Blizzard renames the product folder between releases (classic-era, beta,
forever, retail, …). **The linker does not hardcode a name** — it scans the WoW
root for the subdirectory containing a `.flavor.info` marker. Hardcoding broke
once already when the install moved off the beta, which silently stopped
linking.

Overrides, both optional:

| Variable | Purpose | Default |
|---|---|---|
| `WOW_ROOT` | Directory holding the flavor folders | `~/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft` |
| `WOW_FLAVOR_DIR` | Exact flavor folder; skips detection | auto-detected |
| `DOTFILES_ROOT` | Location of this checkout | `$PWD` if it looks right, else `~/.dotfiles` |

If several flavors are installed, detection is ambiguous and the linker exits
with the candidate paths so you can pick one via `WOW_FLAVOR_DIR`.

### Safety behaviour

- A real (non-symlink) `WTF` or `Interface` in the game folder is **moved aside**
  to `<name>.pre-link-<timestamp>`, never deleted.
- A missing source directory in the repo is a hard error — the linker refuses to
  create dangling symlinks into the game folder.
- A missing WoW install is a hard error too, rather than a silent success.

## Setup

### 1. Enable the feature

Already imported by `profiles/gaming.nix`:

```nix
imports = [ ../features/games/wow-classic ];
```

### 2. Rebuild

```bash
bin/deploy fleet <hostname>
```

This installs the `link-wow-classic` command.

### 3. Link

```bash
bin/wow link          # from the dotfiles root
link-wow-classic      # or the system command, from anywhere
```

## Workflow

### Adding AddOns

Install with WowUp or CurseForge and point the manager at the game's `Interface/AddOns`
— it writes through the symlink into this repo. Then commit:

```bash
git add features/games/wow-classic/Interface/AddOns/
git commit -m "feat(wow): add <AddonName>"
```

Addon managers resolve library dependencies for you; hand-copied addons often
fail with "missing dependency" because a library listed under `## Dependencies:`
or `## RequiredDeps:` in the `.toc` was not fetched.

### Settings changes

`WTF/` updates whenever you change settings, keybinds, macros, or addon config
in game. Commit it like any other change:

```bash
git add features/games/wow-classic/WTF/
git commit -m "chore(wow): update settings"
```

### Giving a new character your settings

```bash
bin/wow seed-character "Some Character"
bin/wow seed-character "Some Character" --from "Other Character"
```

WoW keeps settings at three levels, and only the first two are usable by a
character that has never logged in:

| Level | Path | Covers |
|---|---|---|
| Client | `WTF/Config.wtf` | graphics, sound, cvars |
| Account | `WTF/Account/<slot>/` | keybinds, macros, all addon config |
| Character | `WTF/Account/<slot>/<realm>/<char>/` | action bars, UI layout |

`seed-character` does three things:

1. Copies the account-level payload into **every** account slot. The slot name
   is client-assigned and not stable across installs, so a restore frequently
   lands in a slot the current client never reads — covering all of them is what
   makes keybinds, macros and addon config live on first login.
2. Adds the character to the `profileKeys` table of every AceDB addon
   (Bartender4, Plater, BigWigs, BetterBags, HandyNotes, TomTom, Clique,
   ShadowedUnitFrames, WoWPro), pointing at the template's profile. Without this
   the character silently gets a fresh default profile and comes up unconfigured.
3. Copies the per-character directory into every realm directory present.

Nothing is overwritten without `--force`, so it is safe to re-run — and you
**should** re-run it after the first login, because the realm directory does not
exist until the client creates it.

Note that step 2 makes the character *share* the template's addon profiles, so
later edits affect both. Use the addon's own "new profile → copy from" UI in game
if you want them to diverge.

Character directories replace the space in a two-part name with a hyphen:
`Skelf Onyourshelf` → `Skelf-Onyourshelf`.

### Syncing to a new machine

1. Install WoW
2. `bin/deploy fleet <hostname>`
3. `git submodule update --init --recursive features/games/wow-classic/Interface/AddOns/idAutomation`
4. `bin/wow link`

### The idAutomation submodule

`Interface/AddOns/idAutomation` is a git submodule
(`git@github.com:Industrial/idAutomation.git`), not tracked content. Commit and
push inside the submodule, then bump the pointer in this repo. Restoring addons
from a backup must **exclude** it, or you detach the submodule.

`idAutomation_Bench` is a relative symlink into the submodule's `bench/`
directory — it is a dev-only harness that lives with its source, not a
standalone addon. Keep it a symlink; copying it in creates a second source of
truth.

## What gets tracked

Tracked:

- `Interface/AddOns/` — all addons
- `WTF/Config.wtf` — graphics, sound, cvars
- `WTF/Account/*/` — keybinds (`bindings-cache.wtf`), macros (`macros-cache.txt`)
- `WTF/**/SavedVariables/` — addon settings

Ignored via `.gitignore`: `*.bak`, `*.old`, `*.log`, `WTF/Cache/`.

### Install-identity keys in Config.wtf

`portal` and `agentUID` identify which product the install is. They belong to
the *install*, not to your settings — a `Config.wtf` restored from a beta backup
carries `portal "test"` and `agentUID "wow_classic_beta"`, which points a
non-beta client at test infrastructure. When restoring settings across a product
migration, take these two keys from the new install.

### Account slot directories

The game writes per-WoW-account directories under `WTF/Account/`, named either
`<bnetID>#<slot>` or a legacy account name. The slot number is **not stable
across installs**: the beta used `100021031#5` while the current install writes
`100021031#2` and `2NDUSTRIAL`. All three are kept here so whichever the client
picks finds data.

If your UI comes up at defaults after a migration, the character data is under a
slot the client is not reading. Check which directory the client touched most
recently and rename the restored one to match.

## Troubleshooting

**Nothing links.** Check detection:

```bash
ls -d "$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft"/*/.flavor.info
```

**The game recreated real directories.** Usually a reinstall or repair. Re-run
`bin/wow link`; the fresh directories get archived to `*.pre-link-*`.

**Permission issues.** The Wine prefix must be writable by you:

```bash
ls -la "$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/"
```

## References

- [WowUp — AddOn Manager](https://wowup.io/)
- [WoW AddOns on CurseForge](https://www.curseforge.com/wow/addons)
