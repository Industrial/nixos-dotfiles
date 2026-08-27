# Flakes Reference

## Overview

Flakes provide:
- **Hermetic evaluation** - No impure operations
- **Lock file** - Reproducible dependency versions
- **Standard structure** - Consistent `inputs`/`outputs` schema
- **Composability** - Easy to combine multiple flakes

## Enabling Flakes

```nix
# In configuration.nix or nix.conf
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

## Input Types

### GitHub
```nix
inputs = {
  # Default branch
  nixpkgs.url = "github:NixOS/nixpkgs";

  # Specific branch
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  # Specific commit
  nixpkgs.url = "github:NixOS/nixpkgs/abc123def456";

  # Specific tag
  nixpkgs.url = "github:NixOS/nixpkgs/24.11";

  # Private repo (uses SSH)
  private.url = "github:owner/private-repo";
};
```

### Git
```nix
inputs = {
  # HTTPS
  repo.url = "git+https://git.example.com/repo.git";

  # SSH
  repo.url = "git+ssh://git@github.com/owner/repo.git";

  # Specific branch
  repo.url = "git+https://example.com/repo?ref=develop";

  # Specific tag
  repo.url = "git+https://example.com/repo?tag=v1.0.0";

  # Specific commit
  repo.url = "git+https://example.com/repo?rev=abc123";

  # Shallow clone
  repo.url = "git+ssh://git@github.com/owner/repo?shallow=1";
};
```

### Path (Local)
```nix
inputs = {
  # Local directory
  local.url = "path:/home/user/projects/my-flake";

  # Relative (from flake root)
  local.url = "path:./subdir";
};
```

### Tarball
```nix
inputs = {
  archive.url = "https://example.com/archive.tar.gz";
};
```

### Non-Flake Inputs
```nix
inputs = {
  # Config files, data, etc.
  dotfiles = {
    url = "github:user/dotfiles";
    flake = false;  # Don't evaluate as flake
  };
};

# Usage in outputs:
outputs = { dotfiles, ... }: {
  # Reference files directly
  home.file.".vimrc".source = "${dotfiles}/vimrc";
};
```

## Input Follows

Prevents downloading multiple versions of the same dependency:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  home-manager = {
    url = "github:nix-community/home-manager/release-24.11";
    inputs.nixpkgs.follows = "nixpkgs";  # Use OUR nixpkgs
  };

  # Nested follows
  foo = {
    url = "github:owner/foo";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.bar.follows = "bar";  # If foo has bar as input
  };
};
```

## Flake Outputs Schema

```nix
outputs = { self, nixpkgs, ... }: {
  # ===== Packages =====
  packages.<system>.<name> = derivation;
  packages.x86_64-linux.default = pkgs.hello;
  packages.x86_64-linux.myApp = pkgs.callPackage ./app.nix {};

  # ===== Applications =====
  apps.<system>.<name> = {
    type = "app";
    program = "${package}/bin/executable";
  };

  # ===== Development Shells =====
  devShells.<system>.<name> = pkgs.mkShell { ... };
  devShells.x86_64-linux.default = pkgs.mkShell {
    packages = [ pkgs.nodejs ];
  };

  # ===== NixOS Configurations =====
  nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ ./configuration.nix ];
    specialArgs = { inherit inputs; };  # Pass to modules
  };

  # ===== Darwin Configurations =====
  darwinConfigurations.<hostname> = darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [ ./darwin.nix ];
  };

  # ===== Home Manager Configurations =====
  homeConfigurations."user@host" = home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    modules = [ ./home.nix ];
  };

  # ===== Overlays =====
  overlays.<name> = final: prev: { ... };
  overlays.default = final: prev: {
    myPackage = prev.myPackage.override { ... };
  };

  # ===== NixOS/Darwin Modules =====
  nixosModules.<name> = { config, ... }: { ... };
  darwinModules.<name> = { config, ... }: { ... };

  # ===== Templates =====
  templates.<name> = {
    path = ./template;
    description = "A template";
  };
  templates.default = { ... };

  # ===== Checks (CI) =====
  checks.<system>.<name> = derivation;

  # ===== Formatter =====
  formatter.<system> = pkgs.nixpkgs-fmt;  # or alejandra, nixfmt

  # ===== Library Functions =====
  lib = { ... };

  # ===== Hydra Jobs =====
  hydraJobs.<attr>.<system> = derivation;
};
```

## Lock File (flake.lock)

Auto-generated, contains exact versions:

```json
{
  "nodes": {
    "nixpkgs": {
      "locked": {
        "lastModified": 1234567890,
        "narHash": "sha256-...",
        "owner": "NixOS",
        "repo": "nixpkgs",
        "rev": "abc123...",
        "type": "github"
      }
    }
  }
}
```

## Flake Commands

```bash
# Initialize new flake
nix flake init
nix flake init -t templates#rust  # From template

# Show flake info
nix flake show
nix flake show github:NixOS/nixpkgs

# Show flake metadata
nix flake metadata

# Update all inputs
nix flake update

# Update specific input
nix flake update nixpkgs

# Lock to specific version
nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/abc123

# Check flake
nix flake check

# Build output
nix build .#packageName
nix build .#packages.x86_64-linux.default

# Run output
nix run .#appName

# Enter dev shell
nix develop
nix develop .#shellName

# Archive flake
nix flake archive

# Clone flake
nix flake clone github:owner/repo --dest ./local
```

## Self Reference

The `self` input refers to the current flake:

```nix
outputs = { self, nixpkgs, ... }: {
  packages.x86_64-linux.default = let
    # Access other outputs
    myLib = self.lib;

    # Access flake source
    src = self;
    version = self.rev or self.dirtyRev or "unknown";
  in
    # ...
};
```

## Flake Registry

Named shortcuts for common flakes:

```bash
# List registry
nix registry list

# Add to registry
nix registry add myflake github:owner/repo

# Pin version
nix registry pin nixpkgs

# Remove
nix registry remove myflake

# Use in commands
nix shell nixpkgs#hello  # Uses registry entry
nix shell github:NixOS/nixpkgs#hello  # Explicit
```
