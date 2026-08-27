# Safe NixOS Update Procedure

Based on recent improvements to the NixOS configuration in this repository, here's a safe procedure for updating your system without killing your current user session.

## Key Improvements

1. **User-level update notifier**: `features/cli/nixos-update-notifier/` provides a user timer that checks for updates and sends desktop notifications without performing automatic updates.

2. **Disabled auto-update**: `features/nixos/auto-update/default.nix` explicitly sets `enableAutoUpdate = false;` to prevent background updates that might trigger reboots.

3. **Flake inputs**: Added `nixos-update-notifier-src` to `hosts/<hostname>/flake.nix` for the new notifier feature.

## Safe Update Steps

### 1. Preview Changes
```bash
# See what would change without actually updating
nix flake update
```

### 2. Test Build
```bash
# Build the system configuration to catch compilation errors
nix build .#<your-hostname>
```

### 3. Apply Changes
```bash
# Switch to the new configuration (only restarts services if necessary)
sudo nixos-rebuild switch --flake .#<your-hostname>
```

## Why This Is Safe

- **No automatic reboots**: The auto-update service is disabled
- **User-space notifications**: The update checker runs in user space and only sends notifications
- **Service-level restarts**: `nixos-rebuild switch` only restarts services that actually need it (like after kernel updates)
- **Session preservation**: Graphical sessions (X11/Wayland) typically persist through service restarts unless there are specific breaking changes in graphics drivers or window managers

## Verification

All modified NixOS modules have corresponding `.assay.nix` files that validate the module structure. Run the assay suite to verify changes:

```bash
# Run assays for NixOS modules
moon test -t nixos
```

## When to Reboot

You should only need to reboot after:
- Kernel updates (when a new kernel is selected)
- Critical low-level system updates that require a full restart
- Hardware configuration changes that require reinitialization

In most cases, especially with the improvements in this repository, you can update your NixOS configuration without interrupting your current user session.