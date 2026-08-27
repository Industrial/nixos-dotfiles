# Flake Templates

Ready-to-use `flake.nix` templates for common scenarios.

## Minimal NixOS

```nix
{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}
```

## NixOS + Home Manager

```nix
{
  description = "NixOS with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix

        home-manager.nixosModules.home-manager
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

## nix-darwin (macOS)

```nix
{
  description = "macOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin }: {
    darwinConfigurations.hostname = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";  # or x86_64-darwin for Intel
      modules = [ ./darwin.nix ];
    };
  };
}
```

## nix-darwin + Home Manager

```nix
{
  description = "macOS with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager }: {
    darwinConfigurations.hostname = nix-darwin.lib.darwinSystem {
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

## Standalone Home Manager

```nix
{
  description = "Home Manager standalone";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }: {
    homeConfigurations."username@hostname" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home.nix ];
    };
  };
}

# Apply with: home-manager switch --flake .#username@hostname
```

## Development Shell

```nix
{
  description = "Development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          # Add your dev tools here
          nodejs_20
          yarn
          python3
        ];

        shellHook = ''
          echo "Dev environment ready!"
        '';
      };
    });
}
```

## Multi-Language Dev Shell

```nix
{
  description = "Multi-language development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells = {
        default = pkgs.mkShell {
          packages = with pkgs; [ git vim ];
        };

        node = pkgs.mkShell {
          packages = with pkgs; [ nodejs_20 yarn pnpm ];
          shellHook = ''export PATH="$PWD/node_modules/.bin:$PATH"'';
        };

        python = pkgs.mkShell {
          packages = with pkgs; [ python3 poetry ];
        };

        rust = pkgs.mkShell {
          packages = with pkgs; [ rustc cargo rust-analyzer clippy rustfmt ];
          RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
        };

        go = pkgs.mkShell {
          packages = with pkgs; [ go gopls gotools ];
        };
      };
    });
}

# Usage:
# nix develop .#node
# nix develop .#python
# nix develop .#rust
```

## Cross-Platform (NixOS + Darwin)

```nix
{
  description = "Cross-platform configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-darwin, home-manager, nix-darwin, ... }@inputs: {
    # NixOS configurations
    nixosConfigurations = {
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/desktop/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.username = import ./home/linux.nix;
          }
        ];
        specialArgs = { inherit inputs; };
      };
    };

    # macOS configurations
    darwinConfigurations = {
      macbook = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./hosts/macbook/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.username = import ./home/darwin.nix;
          }
        ];
        specialArgs = { inherit inputs; };
      };
    };
  };
}
```

## Package + DevShell

```nix
{
  description = "Package with development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages = {
        default = pkgs.callPackage ./package.nix { };
      };

      devShells.default = pkgs.mkShell {
        inputsFrom = [ self.packages.${system}.default ];
        packages = with pkgs; [
          # Additional dev tools
          nixpkgs-fmt
        ];
      };
    });
}
```

## With Overlays

```nix
{
  description = "Configuration with overlays";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }: let
    myOverlay = final: prev: {
      myPackage = prev.callPackage ./pkgs/mypackage.nix { };

      # Modify existing package
      vim = prev.vim.override { python3 = final.python311; };
    };
  in {
    # Export overlay for others
    overlays.default = myOverlay;

    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          nixpkgs.overlays = [ myOverlay ];
        }
      ];
    };
  };
}
```

## Starter configuration.nix

```nix
# configuration.nix
{ config, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "hostname";
  networking.networkmanager.enable = true;

  # Time zone
  time.timeZone = "America/New_York";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # Users
  users.users.username = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    vim git curl wget
  ];

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree
  nixpkgs.config.allowUnfree = true;

  # System version (don't change after install)
  system.stateVersion = "24.11";
}
```

## Starter home.nix

```nix
# home.nix
{ config, pkgs, ... }: {
  home.username = "username";
  home.homeDirectory = "/home/username";  # /Users/username on macOS

  home.packages = with pkgs; [
    ripgrep fd jq htop
  ];

  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "you@example.com";
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.starship.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.stateVersion = "24.11";
}
```

## Starter darwin.nix

```nix
# darwin.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    vim git curl
  ];

  # Enable Nix daemon
  services.nix-daemon.enable = true;

  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Zsh (default on macOS)
  programs.zsh.enable = true;

  # System preferences
  system.defaults = {
    dock.autohide = true;
    finder.AppleShowAllExtensions = true;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
  };

  # TouchID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Homebrew (optional)
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [ "firefox" "visual-studio-code" ];
  };

  system.stateVersion = 5;
}
```
