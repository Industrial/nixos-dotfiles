# Skjold

A lightweight Hyprland panel/shell written in Rust using Iced and the `id_effect` framework.

## Features

- **Live workspace bar** - Shows occupied workspaces with click-to-switch
- **Clock** - Current time display
- **Hyprland IPC** - Real-time event subscription for workspace changes
- **id_effect architecture** - Typed capabilities for testable, composable effects

## Architecture

```
src/
├── main.rs           # Entry point
└── lib/
    ├── mod.rs        # Library root
    ├── domain.rs     # Core types (Clock, Workspace)
    ├── capabilities.rs  # Effect traits (HyprlandIpc, TimeService)
    ├── providers.rs  # Live implementations
    └── ui/
        ├── mod.rs
        └── app.rs    # Iced application
```

### Capabilities (id_effect pattern)

- `HyprlandIpc` - Workspace queries and dispatch commands
- `TimeService` - Current time provider

### Event Stream

Hyprland events are received via a dedicated thread bridged to Iced's async runtime:
- `WorkspaceChanged` - Active workspace switched
- `WindowOpened` / `WindowClosed` - Track occupied workspaces

## Usage

### Nested testing (recommended during development)

```bash
nested-hyprland
```

This launches Hyprland in a nested window with Skjold as the shell.

### Direct execution

```bash
skjold
```

Requires a running Hyprland session.

## Development

### Building

```bash
cargo build -p skjold
```

### NixOS

The package is included in the Hyprland feature:
- Binary: `skjoldPkg`
- Nested launcher: `nested-hyprland`

## Roadmap

- [ ] Phase 2: wlr-layer-shell integration (proper panel positioning)
- [ ] System tray
- [ ] Notifications
- [ ] App launcher integration
