# Best Practices

## Configuration Organization

### Modularization

Split large configurations into modules:

```
nixos-config/
├── flake.nix
├── flake.lock
├── hosts/
│   ├── desktop/
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   └── laptop/
│       ├── default.nix
│       └── hardware-configuration.nix
├── modules/
│   ├── common.nix
│   ├── desktop.nix
│   ├── development.nix
│   └── services/
│       ├── nginx.nix
│       └── postgres.nix
├── home/
│   ├── default.nix
│   ├── shell.nix
│   └── programs/
│       ├── git.nix
│       ├── neovim.nix
│       └── tmux.nix
└── overlays/
    └── default.nix
```

### Module Pattern

```nix
# modules/development.nix
{ config, lib, pkgs, ... }: {
  options.myConfig.development = {
    enable = lib.mkEnableOption "development tools";
  };

  config = lib.mkIf config.myConfig.development.enable {
    environment.systemPackages = with pkgs; [
      git vim nodejs
    ];
  };
}

# hosts/desktop/default.nix
{
  imports = [ ../../modules/development.nix ];
  myConfig.development.enable = true;
}
```

## Git Integration

### Version Control Your Config

```bash
# Initialize git in config directory
cd ~/nixos-config
git init
git add .
git commit -m "Initial config"
```

### Critical: Stage Files Before Build

Nix ignores untracked files in flakes:

```bash
# This FAILS if new files aren't staged
sudo nixos-rebuild switch --flake .

# Always stage first
git add .
sudo nixos-rebuild switch --flake .
```

### Move Config from /etc/nixos

```bash
# Option 1: Symlink
sudo mv /etc/nixos /etc/nixos.bak
sudo ln -s ~/nixos-config /etc/nixos

# Option 2: Specify path directly
sudo nixos-rebuild switch --flake ~/nixos-config#hostname
```

## Debugging

### Verbose Output

```bash
# Full debug output
sudo nixos-rebuild switch --flake .#hostname --show-trace --print-build-logs --verbose

# Shorthand
sudo nixos-rebuild switch --flake .#hostname --show-trace -L -v
```

### nix repl

Interactive debugging:

```bash
nix repl

# Load current flake
:lf .

# Explore structure
inputs.<TAB>
outputs.<TAB>
nixosConfigurations.hostname.config.services.<TAB>

# Open package in editor
:e pkgs.hello

# Build derivation
:b pkgs.hello

# Show logs
:log pkgs.hello

# Get derivation path
builtins.toString pkgs.hello
```

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "file not found" | Untracked file | `git add .` |
| "infinite recursion" | Self-referential config | Check `final` vs `prev` in overlays |
| "collision between" | Duplicate packages | Split into different profiles |
| "hash mismatch" | Source changed | Update hash in fetchurl/fetchFromGitHub |

## System Management

### Generation Management

```bash
# List all generations
nix profile history --profile /nix/var/nix/profiles/system

# Delete old generations
sudo nix profile wipe-history --older-than 7d --profile /nix/var/nix/profiles/system

# Garbage collect
sudo nix-collect-garbage -d

# Or just GC without deleting generations
sudo nix store gc
```

### Automatic GC

```nix
# In configuration.nix
{
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Optimize store
  nix.optimise.automatic = true;
}
```

### Boot Entries

```nix
{
  # Limit boot menu entries
  boot.loader.systemd-boot.configurationLimit = 10;

  # Or for GRUB
  boot.loader.grub.configurationLimit = 10;
}
```

## Input Management

### Pin Versions

```bash
# Update all inputs
nix flake update

# Update single input
nix flake update nixpkgs

# Lock to specific commit
nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/abc123
```

### Use follows

Always use `follows` to avoid multiple nixpkgs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  home-manager.inputs.nixpkgs.follows = "nixpkgs";
  nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  # Every input that uses nixpkgs should follow
};
```

### Mixing Stable and Unstable

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
};

outputs = { nixpkgs, nixpkgs-unstable, ... }: {
  nixosConfigurations.host = nixpkgs.lib.nixosSystem {
    modules = [{
      nixpkgs.overlays = [
        (final: prev: {
          unstable = nixpkgs-unstable.legacyPackages.${prev.system};
        })
      ];

      # Use stable by default
      environment.systemPackages = [ pkgs.vim ];

      # Use unstable for specific packages
      programs.firefox.package = pkgs.unstable.firefox;
    }];
  };
};
```

## Remote Deployment

### nixos-rebuild

```bash
# Deploy to remote host
nixos-rebuild switch --flake .#remote-host \
  --target-host user@remote \
  --build-host localhost  # Build locally, deploy result
```

### Colmena

```nix
# flake.nix
{
  outputs = { nixpkgs, ... }: {
    colmena = {
      meta = {
        nixpkgs = import nixpkgs { system = "x86_64-linux"; };
      };

      host1 = {
        deployment = {
          targetHost = "192.168.1.10";
          targetUser = "root";
        };
        imports = [ ./hosts/host1 ];
      };
    };
  };
}

# Deploy
nix run nixpkgs#colmena -- apply
```

## Binary Cache

### Using Cachix

```bash
# Install cachix
nix-env -iA cachix -f https://cachix.org/api/v1/install

# Use a cache
cachix use nix-community

# Or in configuration
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
};
```

## Security

### Secrets Management

Never commit secrets to git. Options:

1. **sops-nix** - Encrypted secrets in repo
2. **agenix** - Age-encrypted secrets
3. **Environment variables** - Runtime injection

```nix
# Example with sops-nix
{
  sops.secrets.my-secret = {
    sopsFile = ./secrets.yaml;
  };

  services.myservice.passwordFile = config.sops.secrets.my-secret.path;
}
```

### Principle of Least Privilege

```nix
{
  # Run services as unprivileged users
  systemd.services.myservice = {
    serviceConfig = {
      DynamicUser = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };
}
```

## Common Patterns

### Conditional Configuration

```nix
{ lib, config, ... }: {
  config = lib.mkMerge [
    # Always applied
    { environment.systemPackages = [ pkgs.vim ]; }

    # Conditional
    (lib.mkIf config.services.xserver.enable {
      environment.systemPackages = [ pkgs.firefox ];
    })
  ];
}
```

### Platform-Specific

```nix
{ pkgs, lib, ... }: {
  environment.systemPackages = with pkgs; [
    git
    vim
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    # Linux only
    inotify-tools
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    # macOS only
    darwin.apple_sdk.frameworks.Security
  ];
}
```

### DRY with Functions

```nix
# lib/mkHost.nix
{ inputs }: hostname: {
  system,
  modules ? [],
  ...
}:
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ../hosts/${hostname}
    ../modules/common.nix
  ] ++ modules;
  specialArgs = { inherit inputs; };
}

# flake.nix
{
  nixosConfigurations = {
    desktop = mkHost "desktop" { system = "x86_64-linux"; };
    laptop = mkHost "laptop" { system = "x86_64-linux"; };
  };
}
```
