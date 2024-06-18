{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-24.05-darwin";
    };
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    darwin,
    ...
  }: let 
    inherit (nixpkgs.lib) nixosSystem;
    inherit (darwin.lib) darwinSystem;
    system = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages.${system};
    settings = {
      hostname = "smithja";
      stateVersion = "24.05";
      system = system;
      hostPlatform = {
        config = "aarch64-apple-darwin";
        system = system;
      };
      userdir = "/Users/twieland";
      useremail = "twieland@suitsupply.com";
      userfullname = "Tom Wieland";
      username = "twieland";
    };
  in {
    darwinConfigurations = {
      smithja = darwinSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          settings = settings // {
            stateVersion = 4;
          };
        };
        modules = [
          ../../features/cli/ansifilter
          ../../features/cli/aria2
          ../../features/cli/bat
          ../../features/cli/btop
          ../../features/cli/direnv
          ../../features/cli/e2fsprogs
          ../../features/cli/eza
          ../../features/cli/fd
          ../../features/cli/fh
          ../../features/cli/fish
          ../../features/cli/fzf
          ../../features/cli/gh
          ../../features/cli/jira-cli
          ../../features/cli/killall
          ../../features/cli/neofetch
          ../../features/cli/p7zip
          ../../features/cli/ranger
          ../../features/cli/ripgrep
          ../../features/cli/starship
          ../../features/cli/unrar
          ../../features/cli/unzip
          ../../features/cli/zellij
          ../../features/communication/discord
          ../../features/crypto/monero
          ../../features/media/spotify
          ../../features/network/sshuttle
          ../../features/nix
          ../../features/nix/nix-daemon
          ../../features/nix/nixpkgs
          ../../features/nix/shell
          ../../features/office/evince
          ../../features/office/obsidian
          ../../features/programming/bun
          ../../features/programming/deno
          ../../features/programming/edgedb
          ../../features/programming/git
          ../../features/programming/gitkraken
          ../../features/programming/glogg
          ../../features/programming/meld
          ../../features/programming/nixd
          ../../features/programming/nodejs
          ../../features/programming/sqlite
          ../../features/programming/vscode
          {
            homebrew.enable = true;
            homebrew.brewPrefix = "/opt/homebrew/bin";
            homebrew.brews = [
              "tor"
              # TODO: This is a cask.
              # "amethyst"
            ];
            # environment.variables = {
            #   http_proxy = "http://127.0.0.1:8080";
            #   https_proxy = "http://127.0.0.1:8080";
            #   socks_proxy = "socks5://127.0.0.1:8080";
            #   ALL_PROXY = "socks5://127.0.0.1:8080";
            # };
            environment.systemPackages = with pkgs; [
              openvpn
              easyrsa
            ];
          }
          {
            nix = {
              distributedBuilds = true;
              linux-builder = {
                enable = true;
                ephemeral = true;
                maxJobs = 4;
                config = {
                  virtualisation = {
                    darwin-builder = {
                      diskSize = 40 * 1024;
                      memorySize = 8 * 1024;
                    };
                    cores = 6;
                  };
                };
              };
              settings = {
                trusted-users = [ "@admin" ];
              };
            };
          }
        ];
      };
    };
    nixosConfigurations = {
      vm = nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          inherit inputs;
          settings = {
            hostname = "vm";
            stateVersion = "24.05";
            system = "aarch64-linux";
            hostPlatform = {
              config = "aarch64-linux";
              system = "aarch64-linux";
            };
            userdir = "/home/tom";
            useremail = "tom.wieland@gmail.com";
            userfullname = "Tom Wieland";
            username = "tom";
          };
        };
        modules = [
          ../../features/cli/ansifilter
          ../../features/cli/appimage-run
          ../../features/cli/bat
          ../../features/cli/btop
          ../../features/cli/direnv
          ../../features/cli/e2fsprogs
          ../../features/cli/eza
          ../../features/cli/fd
          ../../features/cli/fh
          ../../features/cli/fish
          ../../features/cli/fzf
          ../../features/cli/gh
          ../../features/cli/jira-cli
          ../../features/cli/killall
          ../../features/cli/lazygit
          ../../features/cli/neofetch
          ../../features/cli/p7zip
          ../../features/cli/ranger
          ../../features/cli/ripgrep
          ../../features/cli/starship
          #../../features/cli/unrar
          ../../features/cli/unzip
          ../../features/cli/zellij
          ../../features/monitoring/prometheus
          ../../features/network/syncthing
          ../../features/nix
          ../../features/nix/nixpkgs
          ../../features/nix/shell
          ../../features/nixos/console
          ../../features/nixos/fonts
          ../../features/nixos/i18n
          ../../features/nixos/networking
          ../../features/nixos/time
          ../../features/nixos/users
          ../../features/programming/bun
          ../../features/programming/deno
          ../../features/programming/edgedb
          ../../features/programming/git
          ../../features/programming/nixd
          ../../features/programming/nodejs
          ../../features/programming/sqlite
          ../../features/virtual-machine/base
          ../../features/virtual-machine/ssh
          {
            virtualisation = {
              vmVariant = {
                system = {
                  stateVersion = settings.stateVersion;
                };
                virtualisation = {
                  graphics = false;
                  diskSize = 60 * 1024;
                  memorySize = 8 * 1024;
                  host = {
                    pkgs = pkgs;
                  };
                };
              };
            };
          }
        ];
      };
    };
    packages.aarch64-darwin.vm = self.nixosConfigurations.vm.config.system.build.vm;
  };
}
