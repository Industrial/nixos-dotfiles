# Nixpkgs Advanced Usage

## callPackage

`callPackage` auto-injects dependencies from nixpkgs:

```nix
# In your package definition (mypackage.nix)
{ lib, stdenv, fetchFromGitHub, cmake, openssl }:

stdenv.mkDerivation {
  pname = "mypackage";
  version = "1.0.0";
  src = fetchFromGitHub { ... };
  nativeBuildInputs = [ cmake ];
  buildInputs = [ openssl ];
}

# Calling it
pkgs.callPackage ./mypackage.nix { }

# With overrides
pkgs.callPackage ./mypackage.nix {
  openssl = pkgs.openssl_3;
}
```

### How callPackage Works

1. Detects function parameters from `{ lib, stdenv, ... }:`
2. Matches parameters against `pkgs` attributes
3. Injects matched dependencies automatically
4. Second argument allows explicit overrides

### Best Practice

Always use `callPackage` for custom derivations:
- Dependencies are explicit and discoverable
- Easy to override specific inputs
- Follows nixpkgs conventions

## override

Modifies function arguments (inputs to the derivation):

```nix
# Override specific arguments
pkgs.vim.override {
  python3 = pkgs.python311;
}

# Practical examples
pkgs.fcitx5-rime.override {
  rimeDataPkgs = [ ./custom-rime-data ];
}

pkgs.vscode.override {
  commandLineArgs = "--enable-features=UseOzonePlatform";
}

pkgs.firefox.override {
  nativeMessagingHosts = [ pkgs.tridactyl-native ];
}
```

### Finding Override Arguments

```bash
# In nix repl
nix repl -f '<nixpkgs>'
:e pkgs.vim  # Opens in editor

# Or check nixpkgs source on GitHub
```

## overrideAttrs

Modifies derivation attributes (build settings):

```nix
# Basic syntax
pkgs.hello.overrideAttrs (oldAttrs: {
  patches = oldAttrs.patches or [] ++ [ ./my-patch.patch ];
})

# Access and modify multiple attributes
pkgs.myPackage.overrideAttrs (old: rec {
  version = "2.0.0";
  src = pkgs.fetchFromGitHub {
    owner = "owner";
    repo = "repo";
    rev = "v${version}";
    sha256 = "sha256-...";
  };
})

# Disable tests
pkgs.myPackage.overrideAttrs (old: {
  doCheck = false;
})

# Add build flags
pkgs.myPackage.overrideAttrs (old: {
  configureFlags = old.configureFlags or [] ++ [ "--enable-feature" ];
})

# Change phases
pkgs.myPackage.overrideAttrs (old: {
  postInstall = ''
    ${old.postInstall or ""}
    cp extra-file $out/bin/
  '';
})
```

### Common Attributes to Override

| Attribute | Purpose |
|-----------|---------|
| `src` | Source code location |
| `version` | Package version |
| `patches` | List of patches |
| `buildInputs` | Runtime dependencies |
| `nativeBuildInputs` | Build-time dependencies |
| `configureFlags` | ./configure arguments |
| `cmakeFlags` | CMake arguments |
| `doCheck` | Run tests |
| `postInstall` | Post-install commands |

## Overlays

Overlays globally modify nixpkgs. All dependents use the modified version.

### Basic Structure

```nix
# Overlay is a function: final -> prev -> { modifications }
(final: prev: {
  # prev = original package set
  # final = resulting package set (with all overlays applied)

  myPackage = prev.myPackage.override { ... };
})
```

### Using final vs prev

```nix
(final: prev: {
  # Use prev to reference original package
  vim-modified = prev.vim.override { python = prev.python3; };

  # Use final to reference other overlaid packages (avoid infinite recursion)
  myApp = prev.callPackage ./app.nix {
    someLib = final.myLib;  # Uses potentially-overlaid myLib
  };
})
```

### Applying Overlays in Flakes

```nix
# Method 1: In nixosConfiguration
{
  nixpkgs.overlays = [
    (final: prev: {
      myPackage = prev.myPackage.override { ... };
    })

    # Import from file
    (import ./overlays/myoverlay.nix)
  ];
}

# Method 2: When importing nixpkgs
outputs = { nixpkgs, ... }: let
  pkgs = import nixpkgs {
    system = "x86_64-linux";
    overlays = [
      (final: prev: { ... })
    ];
  };
in { ... };
```

### Practical Overlay Examples

```nix
# Chrome with custom flags
(final: prev: {
  google-chrome = prev.google-chrome.override {
    commandLineArgs = [
      "--proxy-server=127.0.0.1:1080"
      "--enable-features=VaapiVideoDecoder"
    ];
  };
})

# Steam with extra packages
(final: prev: {
  steam = prev.steam.override {
    extraPkgs = pkgs: with pkgs; [ keyutils libkrb5 ];
  };
})

# Add custom package
(final: prev: {
  myTool = prev.callPackage ./pkgs/mytool { };
})
```

### Exporting Overlays from Flakes

```nix
outputs = { self, nixpkgs, ... }: {
  # Export overlay for others to use
  overlays.default = final: prev: {
    myPackage = prev.callPackage ./package.nix { };
  };

  # Use in your own config
  nixosConfigurations.host = nixpkgs.lib.nixosSystem {
    modules = [{
      nixpkgs.overlays = [ self.overlays.default ];
    }];
  };
};
```

## Multiple Nixpkgs Instances

When overlays affect too many packages (cache invalidation), use separate instances:

```nix
outputs = { nixpkgs, ... }: let
  system = "x86_64-linux";

  # Main nixpkgs (clean, uses binary cache)
  pkgs = nixpkgs.legacyPackages.${system};

  # Custom nixpkgs with overlays (may build from source)
  pkgsCustom = import nixpkgs {
    inherit system;
    overlays = [ myHeavyOverlay ];
  };
in {
  # Use pkgs for most things
  environment.systemPackages = [ pkgs.vim pkgs.git ];

  # Use pkgsCustom only where needed
  programs.steam.package = pkgsCustom.steam;
};
```

## Unfree Packages

### Method 1: nixpkgs-unfree (Recommended)

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  nixpkgs-unfree.url = "github:numtide/nixpkgs-unfree";
  nixpkgs-unfree.inputs.nixpkgs.follows = "nixpkgs";
};

outputs = { nixpkgs-unfree, ... }: {
  devShells.default = nixpkgs-unfree.legacyPackages.x86_64-linux.mkShell {
    packages = [ nixpkgs-unfree.legacyPackages.x86_64-linux.vscode ];
  };
};
```

### Method 2: Configuration

```nix
# In NixOS/Darwin configuration
{ nixpkgs.config.allowUnfree = true; }

# Or specific packages only
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "slack"
      "discord"
    ];
}
```

### Method 3: User Config

```nix
# ~/.config/nixpkgs/config.nix
{ allowUnfree = true; }
```

**Note:** `nixpkgs.config.allowUnfree` in flake.nix does NOT work with `nix develop`. Use nixpkgs-unfree or user config instead.

## Fetchers

```nix
# From GitHub
src = pkgs.fetchFromGitHub {
  owner = "owner";
  repo = "repo";
  rev = "v1.0.0";  # tag, branch, or commit
  sha256 = "";  # Leave empty first, nix will tell you
};

# From GitLab
src = pkgs.fetchFromGitLab {
  owner = "owner";
  repo = "repo";
  rev = "v1.0.0";
  sha256 = "";
};

# From URL
src = pkgs.fetchurl {
  url = "https://example.com/file.tar.gz";
  sha256 = "";
};

# From Git (with submodules)
src = pkgs.fetchgit {
  url = "https://github.com/owner/repo.git";
  rev = "abc123";
  sha256 = "";
  fetchSubmodules = true;
};

# Get hash for fetchurl
# nix-prefetch-url https://example.com/file.tar.gz

# Get hash for fetchFromGitHub
# nix-prefetch-url --unpack https://github.com/owner/repo/archive/v1.0.0.tar.gz
```
