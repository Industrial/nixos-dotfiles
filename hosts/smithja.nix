{inputs, ...}: let
  name = "smithja";
  system = "aarch64-darwin";
  username = "twieland";
  version = "24.11";
  settings = {
    inherit system username;
    hostname = "${name}";
    stateVersion = "${version}";
    hostPlatform = {
      inherit system;
      config = "aarch64-apple-darwin";
    };
    userdir = "/home/${username}";
    useremail = "${username}@${system}.local";
    userfullname = "${username}";
  };
in {
  "${settings.hostname}" = inputs.nix-darwin.lib.darwinSystem {
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
      # ../features/ai/n8n
      # ../features/ai/ollama
      ../features/cli/bat
      ../features/cli/btop
      ../features/cli/c
      ../features/cli/cheatsheet
      ../features/cli/cl
      ../features/cli/create-ssh-key
      ../features/cli/direnv
      ../features/cli/du
      ../features/cli/dust
      ../features/cli/eza
      ../features/cli/fastfetch
      ../features/cli/fd
      ../features/cli/fish
      ../features/cli/fzf
      ../features/cli/g
      ../features/cli/gpg
      ../features/cli/jq
      ../features/cli/killall
      ../features/cli/l
      # ../features/cli/lazygit
      ../features/cli/ll
      ../features/cli/p
      ../features/cli/p7zip
      ../features/cli/ripgrep
      ../features/cli/starship
      ../features/cli/unrar
      ../features/cli/unzip
      ../features/cli/zellij
      ../features/communication/discord
      #../features/communication/fractal
      ../features/darwin/apple_sdk
      ../features/darwin/settings
      # ../features/games/lutris
      # ../features/games/wowup
      # ../features/media/invidious
      # ../features/media/lidarr
      # ../features/media/prowlarr
      # ../features/media/radarr
      # ../features/media/readarr
      # ../features/media/sonarr
      ../features/media/spotify
      # ../features/media/transmission
      # ../features/media/vlc
      # ../features/media/whisparr
      # ../features/media/calibre
      ../features/media/spotify
      # ../features/monitoring/grafana
      # ../features/monitoring/homepage-dashboard
      # ../features/monitoring/prometheus
      # ../features/network/chromium
      # ../features/network/firefox
      # ../features/network/i2pd
      # ../features/network/searx
      # ../features/network/ssh
      # ../features/network/syncthing
      # ../features/network/tor
      # ../features/network/tor-browser
      ../features/nix
      ../features/nix/nixpkgs
      ../features/nix/users/trusted-users.nix
      # ../features/nixos/bluetooth
      # ../features/nixos/boot
      # ../features/nixos/docker
      # ../features/nixos/fonts
      # ../features/nixos/graphics
      # ../features/nixos/networking
      # ../features/nixos/networking/dns.nix
      # ../features/nixos/networking/firewall.nix
      # ../features/nixos/security/no-defaults
      # ../features/nixos/security/sudo
      # ../features/nixos/sound
      # ../features/
      # ../features/nixos/window-manager
      ../features/office/obsidian
      ../features/programming/bun
      ../features/programming/devenv
      # ../features/programming/docker-compose
      ../features/programming/git
      ../features/programming/gitkraken
      ../features/programming/glogg
      # ../features/programming/insomnia
      ../features/programming/meld
      ../features/programming/node
      ../features/programming/python
      ../features/programming/vscode
      ../features/security/tailscale
      # ../features/security/veracrypt
      # ../features/virtual-machine/base
      # ../features/virtual-machine/kubernetes/k3s
      # ../features/virtual-machine/kubernetes/master
      # ../features/virtual-machine/kubernetes/node
      # ../features/virtual-machine/microvm
      # ../features/virtual-machine/ssh
      # ../features/window-manager/alacritty
      # ../features/window-manager/xfce

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
