{inputs, ...}: {
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
  in
    inputs.nix-darwin.lib.darwinSystem {
      system = settings.system;
      specialArgs = {
        inherit inputs;
        settings =
          settings
          // {
            stateVersion = 4;
          };
      };
      modules = [
        ../features/cli/bat
        ../features/cli/btop
        ../features/cli/c
        ../features/cli/cheatsheet
        ../features/cli/direnv
        ../features/cli/du
        ../features/cli/dust
        ../features/cli/eza
        ../features/cli/fd
        ../features/cli/fish
        ../features/cli/fzf
        ../features/cli/g
        ../features/cli/killall
        ../features/cli/l
        ../features/cli/ll
        ../features/cli/neofetch
        ../features/cli/nushell
        ../features/cli/p7zip
        ../features/cli/ranger
        ../features/cli/ripgrep
        ../features/cli/starship
        ../features/cli/unrar
        ../features/cli/unzip
        ../features/cli/zellij
        ../features/communication/discord
        ../features/crypto/monero
        ../features/darwin/settings
        ../features/media/spotify
        ../features/network/sshuttle
        ../features/nix
        ../features/nix/nix-daemon
        ../features/nix/nixpkgs
        ../features/office/evince
        ../features/office/obsidian
        ../features/programming/bun
        ../features/programming/deno
        ../features/programming/edgedb
        ../features/programming/git
        ../features/programming/gitkraken
        ../features/programming/glogg
        ../features/programming/meld
        ../features/programming/nixd
        ../features/programming/nodejs
        ../features/programming/sqlite
        ../features/programming/vscode

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
}
