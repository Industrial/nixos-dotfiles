# Testing Strategy

This document outlines the testing strategy for our dotfiles repository and lists files that need testing.

## Current Test Coverage

Currently, we have two types of tests:

1. **Unit Tests** (using `bin/test`):
   - Individual module tests in `.test.nix` files
   - Co-located with their implementation
   - Run with `bin/test` or `bin/test --fail-fast`

2. **Integration Tests** (using `tests/default.nix`):
   - Repository structure verification
   - Configuration file existence checks
   - Directory structure validation
   - DevEnv evaluation tests

## Test Organization

We organize tests co-located with their implementation files using the following structure:

```
.
├── common/
│   ├── settings.nix
│   └── settings.test.nix
├── features/
│   ├── cli/
│   │   ├── default.nix
│   │   └── default.test.nix
│   └── window-manager/
│       ├── default.nix
│       └── default.test.nix
├── hosts/
│   ├── mimir/
│   │   ├── default.nix
│   │   └── default.test.nix
│   └── vm_target/
│       ├── default.nix
│       └── default.test.nix
└── tests/
    └── default.nix  # Integration tests
```

## Files Needing Tests

### Common Modules
- [x] `common/settings.nix`

### Features
- [x] `features/ai/n8n/default.nix`
- [x] `features/ai/ollama/default.nix`
- [x] `features/ci/comin/default.nix`
- [x] `features/cli/bat/default.nix`
- [x] `features/cli/btop/default.nix`
- [x] `features/cli/c/default.nix`
- [x] `features/cli/cheatsheet/default.nix`
- [x] `features/cli/cl/default.nix`
- [x] `features/cli/create-ssh-key/default.nix`
- [x] `features/cli/direnv/default.nix`
- [x] `features/cli/du/default.nix`
- [x] `features/cli/dust/default.nix`
- [x] `features/cli/eza/default.nix`
- [x] `features/cli/fastfetch/default.nix`
- [x] `features/cli/fd/default.nix`
- [x] `features/cli/fish/default.nix`
- [x] `features/cli/fish/havamal.nix`
- [x] `features/cli/fzf/default.nix`
- [x] `features/cli/g/default.nix`
- [x] `features/cli/gpg/default.nix`
- [x] `features/cli/jq/default.nix`
- [x] `features/cli/killall/default.nix`
- [x] `features/cli/lazygit/default.nix`
- [x] `features/cli/l/default.nix`
- [x] `features/cli/ll/default.nix`
- [x] `features/cli/p7zip/default.nix`
- [x] `features/cli/p/default.nix`
- [x] `features/cli/ripgrep/default.nix`
- [x] `features/cli/starship/default.nix`
- [x] `features/cli/unrar/default.nix`
- [x] `features/cli/unzip/default.nix`
- [x] `features/cli/zellij/default.nix`
- [ ] `features/communication/discord/default.nix`
- [ ] `features/communication/fractal/default.nix`
- [ ] `features/communication/teams/default.nix`
- [ ] `features/communication/telegram/default.nix`
- [ ] `features/communication/weechat/default.nix`
- [ ] `features/crypto/monero/default.nix`
- [ ] `features/games/lutris/default.nix`
- [ ] `features/games/path-of-building/default.nix`
- [ ] `features/games/wowup/default.nix`
- [ ] `features/media/calibre/default.nix`
- [ ] `features/media/invidious/default.nix`
- [ ] `features/media/jellyfin/default.nix`
- [ ] `features/media/lidarr/default.nix`
- [ ] `features/media/prowlarr/default.nix`
- [ ] `features/media/radarr/default.nix`
- [ ] `features/media/readarr/default.nix`
- [ ] `features/media/sonarr/default.nix`
- [ ] `features/media/spotify/default.nix`
- [ ] `features/media/transmission/default.nix`
- [ ] `features/media/vlc/default.nix`
- [ ] `features/media/whisparr/default.nix`
- [ ] `features/monitoring/grafana/default.nix`
- [ ] `features/monitoring/homepage-dashboard/default.nix`
- [ ] `features/monitoring/prometheus/default.nix`
- [ ] `features/network/chromium/default.nix`
- [ ] `features/network/firefox/default.nix`
- [ ] `features/network/i2pd/default.nix`
- [ ] `features/network/searx/default.nix`
- [ ] `features/network/ssh/default.nix`
- [ ] `features/network/syncthing/default.nix`
- [ ] `features/network/tor-browser/default.nix`
- [ ] `features/network/tor/default.nix`
- [ ] `features/nix/default.nix`
- [ ] `features/nix/nixpkgs/default.nix`
- [ ] `features/nixos/bluetooth/default.nix`
- [ ] `features/nixos/boot/default.nix`
- [ ] `features/nixos/docker/default.nix`
- [ ] `features/nixos/fonts/default.nix`
- [ ] `features/nixos/graphics/amd.nix`
- [ ] `features/nixos/graphics/default.nix`
- [ ] `features/nixos/networking/default.nix`
- [ ] `features/nixos/networking/dns.nix`
- [ ] `features/nixos/networking/firewall.nix`
- [ ] `features/nixos/security/no-defaults/default.nix`
- [ ] `features/nixos/security/sudo/default.nix`
- [ ] `features/nixos/sound/default.nix`
- [ ] `features/nixos/users/default.nix`
- [ ] `features/nixos/window-manager/default.nix`
- [ ] `features/nix/users/trusted-users.nix`
- [ ] `features/office/obsidian/default.nix`
- [ ] `features/programming/bun/default.nix`
- [ ] `features/programming/cursor/default.nix`
- [ ] `features/programming/devenv/default.nix`
- [ ] `features/programming/docker-compose/default.nix`
- [ ] `features/programming/git/default.nix`
- [ ] `features/programming/gitkraken/default.nix`
- [ ] `features/programming/glogg/default.nix`
- [ ] `features/programming/insomnia/default.nix`
- [ ] `features/programming/meld/default.nix`
- [ ] `features/programming/neovim/backup-files.nix`
- [ ] `features/programming/neovim/buffer-search.nix`
- [ ] `features/programming/neovim/buffers.nix`
- [ ] `features/programming/neovim/color-scheme.nix`
- [ ] `features/programming/neovim/commenting.nix`
- [ ] `features/programming/neovim/copy-paste.nix`
- [ ] `features/programming/neovim/dashboard.nix`
- [ ] `features/programming/neovim/debug-adapter-protocol.nix`
- [ ] `features/programming/neovim/default.nix`
- [ ] `features/programming/neovim/diagnostic-signs.nix`
- [ ] `features/programming/neovim/editing.nix`
- [ ] `features/programming/neovim/file-tabs.nix`
- [ ] `features/programming/neovim/file-tree-sidebar.nix`
- [ ] `features/programming/neovim/folds.nix`
- [ ] `features/programming/neovim/git.nix`
- [ ] `features/programming/neovim/indentation.nix`
- [ ] `features/programming/neovim/initialize.nix`
- [ ] `features/programming/neovim/keybind-menu.nix`
- [ ] `features/programming/neovim/language-support.nix`
- [ ] `features/programming/neovim/library.nix`
- [ ] `features/programming/neovim/line-numbers.nix`
- [ ] `features/programming/neovim/movement.nix`
- [ ] `features/programming/neovim/quickfix.nix`
- [ ] `features/programming/neovim/refactoring.nix`
- [ ] `features/programming/neovim/saving-files.nix`
- [ ] `features/programming/neovim/searching.nix`
- [ ] `features/programming/neovim/splits.nix`
- [ ] `features/programming/neovim/status-line.nix`
- [ ] `features/programming/neovim/swap-files.nix`
- [ ] `features/programming/neovim/tab-line.nix`
- [ ] `features/programming/neovim/terminal.nix`
- [ ] `features/programming/neovim/testing.nix`
- [ ] `features/programming/neovim/undo-files.nix`
- [ ] `features/programming/neovim/visual-information.nix`
- [ ] `features/programming/neovim/wildmenu.nix`
- [ ] `features/programming/node/default.nix`
- [ ] `features/programming/python/default.nix`
- [ ] `features/programming/vscode/default.nix`
- [ ] `features/security/keepassxc/default.nix`
- [ ] `features/security/tailscale/default.nix`
- [ ] `features/security/veracrypt/default.nix`
- [ ] `features/virtual-machine/kubernetes/k3s/default.nix`
- [ ] `features/virtual-machine/kubernetes/lib/generateHostEntries.nix`
- [ ] `features/virtual-machine/kubernetes/lib/generateManifest.nix`
- [ ] `features/virtual-machine/kubernetes/lib/generateManifests.nix`
- [ ] `features/virtual-machine/kubernetes/master/default.nix`
- [ ] `features/virtual-machine/kubernetes/node/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/baserow/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/calibre-web/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/dashboard/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/devtron/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/immich/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/jellyfin/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/kube-ops-view/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/openstreetmap/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/pairdrop/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/portainer/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/prowlarr/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/rsshub/default.nix`
- [ ] `features/virtual-machine/kubernetes/services/skooner/default.nix`
- [ ] `features/virtual-machine/microvm/base/default.nix`
- [ ] `features/virtual-machine/microvm/base/gui.nix`
- [ ] `features/virtual-machine/microvm/database/default.nix`
- [ ] `features/virtual-machine/microvm/database/host-network.nix`
- [ ] `features/virtual-machine/microvm/host/default.nix`
- [ ] `features/virtual-machine/microvm/management/default.nix`
- [ ] `features/virtual-machine/microvm/management/host-network.nix`
- [ ] `features/virtual-machine/microvm/ssh/default.nix`
- [ ] `features/virtual-machine/microvm/target/default.nix`
- [ ] `features/virtual-machine/microvm/target/host-network.nix`
- [ ] `features/virtual-machine/microvm/tor/default.nix`
- [ ] `features/virtual-machine/microvm/tor/host-network.nix`
- [ ] `features/virtual-machine/microvm/web/default.nix`
- [ ] `features/virtual-machine/microvm/web/host-network.nix`
- [ ] `features/virtual-machine/ssh/default.nix`
- [ ] `features/virtual-machine/virtualbox/default.nix`
- [ ] `features/window-manager/alacritty/default.nix`
- [ ] `features/window-manager/dwm/default.nix`
- [ ] `features/window-manager/dwm/overlays/my-dwm.nix`
- [ ] `features/window-manager/ghostty/default.nix`
- [ ] `features/window-manager/gnome/default.nix`
- [ ] `features/window-manager/river/default.nix`
- [ ] `features/window-manager/slock/default.nix`
- [ ] `features/window-manager/stylix/default.nix`
- [ ] `features/window-manager/stylix/derivations/tinted-theming-schemes.nix`
- [ ] `features/window-manager/xclip/default.nix`
- [ ] `features/window-manager/xfce/default.nix`
- [ ] `features/window-manager/xmonad/default.nix`
- [ ] `features/window-manager/xsel/default.nix`

### Hosts
- [ ] `hosts/drakkar/flake.nix`
- [ ] `hosts/huginn/flake.nix`
- [ ] `hosts/langhus/flake.nix`
- [ ] `hosts/mimir/disko.nix`
- [ ] `hosts/mimir/filesystems.nix`
- [ ] `hosts/mimir/flake.nix`
- [ ] `hosts/vm_database/flake.nix`
- [ ] `hosts/vm_management/flake.nix`
- [ ] `hosts/vm_target/flake.nix`
- [ ] `hosts/vm_test/flake.nix`
- [ ] `hosts/vm_tor/flake.nix`
- [ ] `hosts/vm_web/flake.nix`

## Test Types

For each module, we should test:

1. **Basic Evaluation**
   - Module evaluates without errors
   - Required attributes are present
   - Type checking of values

2. **Integration**
   - Module composes correctly with other modules
   - Dependencies are satisfied
   - No conflicts with other modules

3. **Functionality**
   - Module produces expected outputs
   - Configuration values are correctly applied
   - Edge cases are handled properly

## Running Tests

Tests can be run like this:

1. **Unit Tests (Recommended)**
   ```bash
   bin/test
   ```
   This will run all `.test.nix` files in the repository.

Tests are automatically run:
- Before each commit (pre-commit hook): Integration tests
- Before each push (pre-push hook): Unit tests
- In CI/CD pipeline: Both unit and integration tests
