# NixOS Dotfiles

[![CI - PR](https://github.com/Industrial/nixos-dotfiles/actions/workflows/pr.yml/badge.svg)](https://github.com/Industrial/nixos-dotfiles/actions/workflows/pr.yml)
[![CI - Main](https://github.com/Industrial/nixos-dotfiles/actions/workflows/main.yml/badge.svg)](https://github.com/Industrial/nixos-dotfiles/actions/workflows/main.yml)

My NixOS configuration. I have separated out all software into features and
avoided [HomeManager](https://github.com/nix-community/home-manager) to make it
more portable. The caveat is that you have to configure everything manually but
hey it's nix so that's pretty easy!

## Hosts

This repository manages the following NixOS hosts:

- **drakkar** - Desktop workstation
- **huginn** - Tablet ([StarLite 5](https://us.starlabs.systems/products/starlite))
- **mimir** - Server

Each host has its own flake configuration in the `hosts/` directory.

## Installation

```bash
git clone git@github.com:Industrial/nixos-dotfiles.git ~/.dotfiles
```

For detailed installation instructions for specific hosts, see the `hosts/<hostname>/INSTALL.md` file (if available).

## Update

Update the current host system:

```bash
bin/update/host
```

This will:
- Update the system using `nixos-rebuild switch`
- Update the login shell
- Link necessary files for certain features

Other update commands:

- `bin/update/system` - Update system only
- `bin/update/flake` - Update flake lock files
- `bin/update/channels` - Update NixOS channels
- `bin/update/profiles` - Update profiles
- `bin/update/repositories` - Update git repositories
- `bin/update/login-shell` - Update login shell only

## System Management

### Generations

List, rollback, or delete system generations:

```bash
bin/generations/list      # List all system generations
bin/generations/rollback  # Rollback to previous generation
bin/generations/delete    # Delete old generations (keeps last 2)
```

### Cleanup

Collect garbage to free up disk space:

```bash
bin/delete/collectgarbage
```

## Development

This repository uses [devenv.sh](https://devenv.sh/) for development environment management. Devenv provides a consistent development environment with all necessary tools and dependencies configured through Nix.

### Getting Started

Enter the devenv shell:

```bash
devenv shell
```

This will activate the development environment with all necessary tools and dependencies.

The devenv environment includes:
- Nix development tools (nix-unit, namaka, nixt)
- Rust toolchain (rustc, cargo, rustfmt, clippy, rust-analyzer)
- Formatting tools (treefmt, alejandra, deadnix, biome, etc.)
- Security scanning tools (clamav, lynis, vulnix)
- And more...

For more information about devenv, see the [devenv.sh documentation](https://devenv.sh/).

### Development Workflow

1. Make your changes
2. Format code (if needed):
   ```bash
   treefmt
   ```
3. Commit your changes:
   ```bash
   git commit -m "your message"
   ```

The CI pipeline will automatically check formatting, run security scans, and validate configurations for all hosts.

## Project Structure

```
.
├── bin/              # Utility scripts
├── common/           # Common NixOS configuration
├── config/           # Configuration files
├── features/         # Feature modules (organized by category)
├── hosts/            # Host-specific configurations
│   ├── drakkar/      # Desktop workstation
│   ├── huginn/       # Server
│   └── mimir/        # Server
├── profiles/         # User profiles
└── devenv.nix        # Development environment configuration
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Ensure all CI checks pass
5. Commit your changes (`git commit -m 'Add some amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is released into the public domain. See [LICENSE](LICENSE) for details.
