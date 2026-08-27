# nix-darwin Reference

## Overview

nix-darwin brings NixOS-style declarative configuration to macOS:
- System preferences
- Homebrew management
- launchd services
- User shell configuration

## Installation

```bash
# Install Nix first (use Determinate Nix or official installer)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh

# Create config directory
mkdir -p ~/.config/nix
cd ~/.config/nix

# Initialize flake from template
nix flake init -t nix-darwin

# Build and activate (first time)
nix run nix-darwin -- switch --flake .

# Subsequent rebuilds
darwin-rebuild switch --flake .
```

## Basic flake.nix

```nix
{
  description = "Darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nix-darwin, nixpkgs }: {
    darwinConfigurations."hostname" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";  # Apple Silicon
      # system = "x86_64-darwin";  # Intel Mac
      modules = [ ./darwin.nix ];
    };
  };
}
```

## Basic darwin.nix

```nix
{ pkgs, ... }: {
  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
  ];

  # Enable Nix daemon
  services.nix-daemon.enable = true;

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Binary caches
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # Shell
  programs.zsh.enable = true;  # default shell on macOS

  # Required for nix-darwin
  system.stateVersion = 5;
}
```

## System Preferences

### Dock
```nix
{
  system.defaults.dock = {
    autohide = true;
    autohide-delay = 0.0;
    autohide-time-modifier = 0.2;
    orientation = "bottom";  # left, bottom, right
    show-recents = false;
    static-only = false;  # Show only open apps
    tilesize = 48;
    mineffect = "scale";  # genie, scale, suck
    minimize-to-application = true;
    launchanim = false;
    mru-spaces = false;  # Don't rearrange spaces
  };
}
```

### Finder
```nix
{
  system.defaults.finder = {
    AppleShowAllExtensions = true;
    AppleShowAllFiles = true;  # Show hidden files
    ShowPathbar = true;
    ShowStatusBar = true;
    FXDefaultSearchScope = "SCcf";  # Current folder
    FXEnableExtensionChangeWarning = false;
    FXPreferredViewStyle = "clmv";  # Column view
    _FXShowPosixPathInTitle = true;
    QuitMenuItem = true;  # Allow quitting Finder
  };
}
```

### Keyboard
```nix
{
  system.defaults.NSGlobalDomain = {
    # Keyboard
    KeyRepeat = 2;
    InitialKeyRepeat = 15;
    ApplePressAndHoldEnabled = false;  # Key repeat instead of accents

    # Mouse/Trackpad
    AppleEnableMouseSwipeNavigateWithScrolls = true;
    AppleEnableSwipeNavigateWithScrolls = true;
    "com.apple.swipescrolldirection" = true;  # Natural scrolling

    # UI
    AppleInterfaceStyle = "Dark";
    AppleShowAllExtensions = true;
    NSAutomaticCapitalizationEnabled = false;
    NSAutomaticSpellingCorrectionEnabled = false;
    NSAutomaticPeriodSubstitutionEnabled = false;
    NSAutomaticQuoteSubstitutionEnabled = false;
    NSAutomaticDashSubstitutionEnabled = false;
  };
}
```

### Trackpad
```nix
{
  system.defaults.trackpad = {
    Clicking = true;  # Tap to click
    TrackpadRightClick = true;
    TrackpadThreeFingerDrag = true;
  };
}
```

### Screenshots
```nix
{
  system.defaults.screencapture = {
    location = "~/Screenshots";
    type = "png";
    disable-shadow = true;
  };
}
```

## TouchID for sudo

```nix
{
  security.pam.services.sudo_local.touchIdAuth = true;
}
```

## Homebrew Integration

nix-darwin can manage Homebrew declaratively:

```nix
{
  homebrew = {
    enable = true;

    # Uninstall packages not in config
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";  # uninstall + remove caches
      upgrade = true;
    };

    # Taps
    taps = [
      "homebrew/services"
    ];

    # CLI tools
    brews = [
      "mas"  # Mac App Store CLI
    ];

    # GUI apps
    casks = [
      "firefox"
      "visual-studio-code"
      "docker"
      "raycast"
      "1password"
    ];

    # Mac App Store apps (requires mas)
    masApps = {
      "Xcode" = 497799835;
      "Keynote" = 409183694;
    };
  };
}
```

## Services (launchd)

```nix
{
  # Built-in services
  services.yabai.enable = true;  # Tiling WM
  services.skhd.enable = true;   # Hotkey daemon
  services.sketchybar.enable = true;

  # Custom launchd service
  launchd.user.agents.myservice = {
    serviceConfig = {
      Label = "com.example.myservice";
      Program = "${pkgs.myapp}/bin/myapp";
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/myservice.log";
      StandardErrorPath = "/tmp/myservice.err";
    };
  };
}
```

## Fonts

```nix
{
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })
    inter
    sf-mono
  ];
}
```

## Environment

```nix
{
  environment = {
    # System-wide packages
    systemPackages = with pkgs; [ vim git ];

    # Environment variables
    variables = {
      EDITOR = "vim";
    };

    # Shell init (all shells)
    shellInit = ''
      export PATH="$HOME/.local/bin:$PATH"
    '';
  };
}
```

## Home Manager Integration

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nix-darwin, home-manager, ... }: {
    darwinConfigurations."hostname" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./darwin.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.username = import ./home.nix;
        }
      ];
    };
  };
}
```

## Commands

```bash
# Rebuild and switch
darwin-rebuild switch --flake .#hostname

# Build without switching
darwin-rebuild build --flake .#hostname

# Check configuration
darwin-rebuild check --flake .#hostname

# Rollback
darwin-rebuild --rollback

# List generations
darwin-rebuild --list-generations
```

## Useful Defaults Commands

```bash
# Find preference keys
defaults read > before.txt
# Change setting in System Preferences
defaults read > after.txt
diff before.txt after.txt

# Read specific domain
defaults read com.apple.dock

# Read specific key
defaults read com.apple.dock autohide
```
