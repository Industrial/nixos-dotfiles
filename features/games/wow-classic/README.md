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

### 1. Copy Existing Configuration (First Time Only)

If you already have WoW Classic installed with settings and AddOns:

```bash
# Copy WTF directory (settings, saved variables)
cp -r "/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/WTF" \
      ~/.dotfiles/features/games/wow-classic/

# Copy Interface directory (AddOns)
cp -r "/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/Interface" \
      ~/.dotfiles/features/games/wow-classic/

# Remove originals (will be replaced by symlinks on next rebuild)
rm -rf "/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/WTF"
rm -rf "/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/Interface"
```

### 2. Enable the Feature

Add to your host configuration or user imports:

```nix
imports = [
  ./features/games/wow-classic
];
```

### 3. Rebuild

```bash
bin/deploy fleet <hostname>
# or
home-manager switch
```

The symlinks will be created automatically.

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
2. Enable this feature module
3. Rebuild with `bin/deploy` or `home-manager switch`
4. All settings and AddOns are automatically linked

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
