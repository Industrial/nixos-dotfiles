{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    # ansifilter.url = "path:./../../features/cli/ansifilter";
    # ansifilter.inputs.nixpkgs.follows = "nixpkgs";

    # Unfortunately, for now, these paths need to be absolute.
    # TODO: Create a helper that makes it absolute paths and adds the
    #       `inputs.nixpkgs.follows = "nixpkgs";`.
    aria2.url = "path:/Users/twieland/.dotfiles/features/cli/aria2";
    # aria2.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs@{ ... }: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = inputs.nixpkgs.lib.systems.flakeExposed;
    flake = {
      darwinConfigurations = {
        smithja = let
          settings = {
            hostname = "smithja";
            stateVersion = "24.05";
            system = "aarch64-darwin";
            hostPlatform = {
              config = "aarch64-apple-darwin";
              system = "aarch64-darwin";
            };
            userdir = "/Users/twieland";
            useremail = "twieland@suitsupply.com";
            userfullname = "Tom Wieland";
            username = "twieland";
          };
        in inputs.nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {
            inherit inputs;
            settings = settings // {
              stateVersion = 4;
            };
          };
          modules = [
            # inputs.ansifilter.nixosModules
            inputs.aria2.nixosModules.aria2
            features/cli/bat
            # features/cli/btop
            features/cli/direnv
            # features/cli/e2fsprogs
            features/cli/eza
            # features/cli/fd
            # features/cli/fh
            features/cli/fish
            features/cli/fzf
            # features/cli/gh
            # features/cli/jira-cli
            # features/cli/killall
            # features/cli/neofetch
            # features/cli/p7zip
            # features/cli/ranger
            # features/cli/ripgrep
            features/cli/starship
            # features/cli/unrar
            # features/cli/unzip
            # features/cli/zellij
            features/communication/discord
            # features/crypto/monero
            features/media/spotify
            # features/network/sshuttle
            features/nix
            features/nix/nix-daemon
            features/nix/nixpkgs
            features/nix/shell
            # features/office/evince
            features/office/obsidian
            # features/programming/bun
            # features/programming/deno
            # features/programming/edgedb
            features/programming/git
            features/programming/gitkraken
            # features/programming/glogg
            # features/programming/meld
            # features/programming/nixd
            # features/programming/nodejs
            # features/programming/sqlite
            features/programming/vscode

            # {
            #   homebrew.enable = true;
            #   homebrew.brewPrefix = "/opt/homebrew/bin";
            #   homebrew.brews = [
            #     "tor"
            #     # TODO: This is a cask.
            #     # "amethyst"
            #   ];
            #   # environment.variables = {
            #   #   http_proxy = "http://127.0.0.1:8080";
            #   #   https_proxy = "http://127.0.0.1:8080";
            #   #   socks_proxy = "socks5://127.0.0.1:8080";
            #   #   ALL_PROXY = "socks5://127.0.0.1:8080";
            #   # };
            #   environment.systemPackages = with pkgs; [
            #     openvpn
            #     easyrsa
            #   ];
            # }

            # {
            #   nix = {
            #     distributedBuilds = true;
            #     linux-builder = {
            #       enable = true;
            #       ephemeral = true;
            #       maxJobs = 4;
            #       config = {
            #         virtualisation = {
            #           darwin-builder = {
            #             diskSize = 40 * 1024;
            #             memorySize = 8 * 1024;
            #           };
            #           cores = 6;
            #         };
            #       };
            #     };
            #     settings = {
            #       trusted-users = [ "@admin" ];
            #     };
            #   };
            # }
          ];
        };
      };
    };

    # perSystem = { self', inputs', pkgs, system, config, ... }: {
    #   # # TODO: Replace with flake-parts system.
    #   # # TODO: Put in file.
    #   # # packages.aarch64-darwin.vm = self.nixosConfigurations.vm.config.system.build.vm;

    #   # treefmt.config = {
    #   #   projectRootFile = "flake.nix";
    #   #   programs.nixpkgs-fmt.enable = true;
    #   # };

    #   # packages.default = self'.packages.activate;

    #   # devShells.default = pkgs.mkShell {
    #   #   inputsFrom = [
    #   #     # inputs'.ansifilter.packages.${system}.default
    #   #     # config.treefmt.build.devShell
    #   #   ];
    #   #   packages = with pkgs; [
    #   #     # just
    #   #     # colmena
    #   #     nixd
    #   #     # inputs'.ragenix.packages.default
    #   #   ];
    #   # };

    #   # systemConfigs.default = {
    #   # } // inputs.ansifilter.systemConfigs.${system}.default;
    # };
  };
}

