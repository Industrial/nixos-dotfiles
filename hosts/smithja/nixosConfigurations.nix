{ inputs, settings, pkgs, ... }: {
    nixosConfigurations = {
      vm = inputs.nixosSystem {
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
}