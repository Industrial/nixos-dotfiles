# Home Manager Reference

## Overview

Home Manager manages user-specific:
- Packages in `~/.nix-profile`
- Dotfiles in `~/.config`, `~/.*`
- User services
- Shell configuration

## Installation Methods

### As NixOS Module
```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.username = import ./home.nix;
          # Pass extra args to home.nix
          home-manager.extraSpecialArgs = { inherit inputs; };
        }
      ];
    };
  };
}
```

### As Darwin Module
```nix
# Same pattern as NixOS
{
  outputs = { nix-darwin, home-manager, ... }: {
    darwinConfigurations.hostname = nix-darwin.lib.darwinSystem {
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

### Standalone
```nix
# flake.nix
{
  outputs = { nixpkgs, home-manager, ... }: {
    homeConfigurations."user@hostname" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home.nix ];
      extraSpecialArgs = { inherit inputs; };
    };
  };
}

# Apply with:
# home-manager switch --flake .#user@hostname
```

## Basic home.nix

```nix
{ config, pkgs, ... }: {
  home.username = "username";
  home.homeDirectory = "/home/username";  # /Users/username on macOS

  # Packages
  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    htop
  ];

  # IMPORTANT: Match your Home Manager version
  home.stateVersion = "24.11";

  # Let Home Manager manage itself (standalone only)
  programs.home-manager.enable = true;
}
```

## File Management

```nix
{
  # Copy file
  home.file.".config/app/config.toml".source = ./config.toml;

  # Create from text
  home.file.".config/app/config.toml".text = ''
    [section]
    key = "value"
  '';

  # Symlink
  home.file.".config/app".source = config.lib.file.mkOutOfStoreSymlink ./app-config;

  # Executable script
  home.file.".local/bin/myscript" = {
    executable = true;
    text = ''
      #!/bin/bash
      echo "Hello"
    '';
  };

  # Recursive directory
  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

  # XDG config (equivalent to ~/.config)
  xdg.configFile."app/config.toml".source = ./config.toml;
}
```

## Program Modules

Home Manager has built-in modules for many programs:

### Git
```nix
{
  programs.git = {
    enable = true;
    userName = "Your Name";
    userEmail = "you@example.com";

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };

    aliases = {
      co = "checkout";
      st = "status";
    };

    ignores = [ ".DS_Store" "*.swp" ];

    signing = {
      key = "KEYID";
      signByDefault = true;
    };

    delta.enable = true;  # Better diffs
  };
}
```

### Shell (Zsh)
```nix
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -la";
      update = "sudo nixos-rebuild switch --flake .#hostname";
    };

    initExtra = ''
      # Custom init
      export PATH="$HOME/.local/bin:$PATH"
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" ];
      theme = "robbyrussell";
    };
  };
}
```

### Shell (Fish)
```nix
{
  programs.fish = {
    enable = true;
    shellAliases = { ll = "ls -la"; };
    shellInit = ''
      set -gx PATH $HOME/.local/bin $PATH
    '';
    plugins = [
      { name = "z"; src = pkgs.fishPlugins.z.src; }
    ];
  };
}
```

### Neovim
```nix
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      telescope-nvim
      nvim-lspconfig
    ];

    extraLuaConfig = ''
      -- Lua config here
      vim.opt.number = true
    '';

    extraPackages = with pkgs; [
      lua-language-server
      nil  # Nix LSP
    ];
  };
}
```

### Starship Prompt
```nix
{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character.success_symbol = "[➜](bold green)";
    };
  };
}
```

### Direnv
```nix
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;  # Better Nix integration
  };
}
```

### Tmux
```nix
{
  programs.tmux = {
    enable = true;
    clock24 = true;
    baseIndex = 1;
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
    ];
    extraConfig = ''
      set -g mouse on
    '';
  };
}
```

## Environment Variables

```nix
{
  home.sessionVariables = {
    EDITOR = "nvim";
    BROWSER = "firefox";
    MY_VAR = "value";
  };

  # Path additions
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];
}
```

## User Services (systemd)

```nix
{
  # Linux only
  systemd.user.services.myservice = {
    Unit.Description = "My Service";
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart = "${pkgs.myapp}/bin/myapp";
      Restart = "always";
    };
  };
}
```

## macOS (launchd)

```nix
{
  # macOS only
  launchd.agents.myservice = {
    enable = true;
    config = {
      Program = "${pkgs.myapp}/bin/myapp";
      RunAtLoad = true;
      KeepAlive = true;
    };
  };
}
```

## Activation Scripts

```nix
{
  home.activation = {
    myScript = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Run after home-manager writes files
      $DRY_RUN_CMD mkdir -p $HOME/.cache/myapp
    '';
  };
}
```

## NixOS vs Home Manager

| Aspect | NixOS | Home Manager |
|--------|-------|--------------|
| Scope | System-wide | Per-user |
| Requires | Root | No root needed |
| Services | systemd system | systemd user |
| Location | /etc, /run | ~/.config, ~/ |
| Packages | Available to all | User-specific |

**Use NixOS for:**
- System services (nginx, postgres)
- Hardware configuration
- Boot, kernel, networking
- System-wide packages

**Use Home Manager for:**
- User dotfiles
- User packages
- Shell configuration
- Desktop apps
- Portable configs (use across systems)
