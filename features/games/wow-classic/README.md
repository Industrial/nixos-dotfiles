# World of Warcraft Classic Configuration

This feature module manages World of Warcraft Classic settings, AddOns, and configurations by symlinking them from your dotfiles to the Wine prefix.

## Directory Structure

```
features/games/wow-classic/
├── default.nix          # NixOS/home-manager module
├── default.assay.nix    # Tests
├── WTF/                 # Settings, saved variables, account data
└── Interface/           # AddOns
    └── AddOns/          # Individual addon directories
```

## How It Works

The module creates out-of-store symlinks from your dotfiles to the WoW installation:

- `~/.dotfiles/features/games/wow-classic/WTF/` → `/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/WTF/`
- `~/.dotfiles/features/games/wow-classic/Interface/` → `/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/Interface/`

**Out-of-store symlinks** mean the game can write to these files, and changes are immediately reflected in your dotfiles repo.

## Initial Setup

### 1. Enable the Feature

Add to your host configuration (e.g., in `profiles/gaming.nix`):

```nix
imports = [
  ./features/games/wow-classic
];
```

### 2. Rebuild System

```bash
bin/deploy fleet <hostname>
# or
nixos-rebuild switch
```

This installs the `link-wow-classic` command.

### 3. Copy Existing Configuration (First Time Only)

If you already have WoW Classic installed with settings and AddOns:

```bash
# From dotfiles root directory
cd ~/.dotfiles

# Copy WTF directory (settings, saved variables)
cp -r "/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/WTF" \
      features/games/wow-classic/

# Copy Interface directory (AddOns)
cp -r "/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/Interface" \
      features/games/wow-classic/

# Commit to git
git add features/games/wow-classic/
git commit -m "feat(wow): add existing WoW Classic configuration"
```

### 4. Create Symlinks

Run the linking script to symlink dotfiles to WoW installation:

```bash
# From dotfiles root directory
bin/wow link
# or use the system command directly:
link-wow-classic
```

This will:
- Remove existing WTF and Interface directories in the WoW installation
- Create symlinks pointing to your dotfiles
- Display confirmation of symlink creation

## Workflow

### Adding New AddOns

**Option 1: Install via WoW AddOn Manager (Recommended)**
1. Use WowUp, CurseForge, or install manually
2. AddOns appear in `~/.dotfiles/features/games/wow-classic/Interface/AddOns/`
3. Commit the new AddOns to git:
   ```bash
   git add features/games/wow-classic/Interface/AddOns/
   git commit -m "feat(wow): add <AddonName> addon"
   ```

**Option 2: Manual Installation**
1. Download addon
2. Extract to `~/.dotfiles/features/games/wow-classic/Interface/AddOns/<AddonName>/`
3. Commit to git

**⚠️ Important: Addon Dependencies**

Some addons require library dependencies (e.g., Memento requires ArcaneWizardLibrary). When manually copying addons:
- **Recommended**: Use WowUp or CurseForge client - they automatically download dependencies
- **Manual approach**: If you see errors like "missing dependency", either:
  - Install via addon manager which handles dependencies
  - Manually download and add the required library
  - Remove the addon if you don't need it

Dependencies are usually listed in the addon's `.toc` file under `## Dependencies:` or `## RequiredDeps:`.

### Settings Changes

Settings are automatically saved to `WTF/` when you:
- Change in-game settings
- Modify addon configurations
- Switch characters or realms

Just commit the changes:
```bash
git add features/games/wow-classic/WTF/
git commit -m "chore(wow): update settings"
```

### Syncing to New Machine

On a new machine with the same dotfiles:
1. Install WoW Classic via Lutris
2. Enable this feature module in your host config
3. Rebuild with `bin/deploy fleet <hostname>`
4. Run `bin/wow link` to create symlinks
5. All settings and AddOns are now linked!

## Important Directories in WTF/

- `WTF/Account/<AccountName>/` - Account-wide settings
- `WTF/Account/<AccountName>/<Realm>/<Character>/` - Character-specific settings
- `WTF/Account/<AccountName>/SavedVariables/` - Account-wide addon data
- `WTF/Account/<AccountName>/<Realm>/<Character>/SavedVariables/` - Character-specific addon data
- `WTF/Config.wtf` - Global client configuration

## Git Considerations

### What to Track

**Always track:**
- Interface/AddOns/ (your addons)
- WTF/Config.wtf (graphics, keybinds)
- WTF/Account/*/SavedVariables/ (addon settings)

**Consider .gitignore:**
- `WTF/Cache/` (cache files)
- `*.bak` (backup files)
- `*.old` (old config files)

### .gitignore Example

Create `features/games/wow-classic/.gitignore`:
```
# Cache and temporary files
WTF/Cache/
*.bak
*.old

# Logs (if any get created)
*.log
```

## Troubleshooting

### Symlinks Not Created

The module only creates symlinks if the WoW path exists:
```bash
# Check if path exists
ls -la "/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/"
```

### Permission Issues

Ensure the Wine prefix is writable:
```bash
ls -la "/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/"
# Should show 'tom' as owner
```

### Changes Not Appearing

Out-of-store symlinks mean:
- Changes in WoW → immediately in dotfiles
- Changes in dotfiles → immediately in WoW
- No rebuild needed for content changes
- Rebuild only needed if you modify `default.nix`

## Alternative: Selective AddOn Tracking

If you prefer to track only specific AddOns, edit `default.nix`:

```nix
# Instead of symlinking entire Interface directory:
home.file."${wowClassicPath}/Interface/AddOns/WeakAuras" = {
  source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWowPath}/Interface/AddOns/WeakAuras";
  recursive = true;
};

home.file."${wowClassicPath}/Interface/AddOns/Details" = {
  source = config.lib.file.mkOutOfStoreSymlink "${dotfilesWowPath}/Interface/AddOns/Details";
  recursive = true;
};
```

## References

- [Home Manager Manual - home.file](https://nix-community.github.io/home-manager/options.html#opt-home.file)
- [WowUp - AddOn Manager](https://wowup.io/)
- [WoW Classic AddOns on CurseForge](https://www.curseforge.com/wow/addons)
