{inputs, ...}: let
  name = "langhus";
  system = "x86_64-linux";
  username = "tom";
  version = "24.05";
  settings = {
    inherit system username;
    hostname = "${name}";
    stateVersion = "${version}";
    hostPlatform = {
      inherit system;
    };
    userdir = "/home/${username}";
    useremail = "${username}@${system}.local";
    userfullname = "${username}";
  };
in {
  "${settings.hostname}" = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs settings;
    };
    modules = [
      ../features/cli/appimage-run
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
      ../features/cli/killall
      ../features/cli/l
      ../features/cli/lazygit
      ../features/cli/ll
      ../features/cli/p7zip
      ../features/cli/ripgrep
      ../features/cli/starship
      ../features/cli/unrar
      ../features/cli/unzip
      ../features/cli/zellij
      ../features/communication/discord
      ../features/communication/fractal
      ../features/games/lutris
      ../features/games/path-of-building
      ../features/games/steam
      ../features/games/wowup
      # ../features/hardware/zsa-keyboard
      ../features/media/gimp
      ../features/media/invidious
      ../features/media/lidarr
      ../features/media/okular
      ../features/media/prowlarr
      ../features/media/radarr
      ../features/media/readarr
      ../features/media/sonarr
      ../features/media/spotify
      ../features/media/transmission
      ../features/media/vlc
      # ../features/media/whisparr
      ../features/monitoring/grafana
      ../features/monitoring/homepage-dashboard
      ../features/monitoring/prometheus
      ../features/network/chromium
      ../features/network/firefox
      # ../features/network/i2pd
      ../features/network/syncthing
      # ../features/network/tor
      ../features/network/tor-browser
      ../features/nix
      # ../features/nix/nix-daemon
      ../features/nix/nix-unit
      ../features/nix/nixpkgs
      ../features/nixos/bluetooth
      ../features/nixos/boot
      ../features/nixos/console
      # ../features/nixos/docker
      ../features/nixos/fonts
      ../features/nixos/graphics
      ../features/nixos/i18n
      ../features/nixos/networking
      ../features/nixos/security/apparmor
      ../features/nixos/security/yubikey
      ../features/nixos/sound
      ../features/nixos/system
      ../features/nixos/time
      ../features/nixos/users
      ../features/nixos/window-manager
      ../features/office/cryptpad
      ../features/office/obsidian
      # ../features/programming/android-tools
      ../features/programming/devenv
      # ../features/programming/docker-compose
      ../features/programming/git
      ../features/programming/gitkraken
      ../features/programming/glogg
      # ../features/programming/insomnia
      ../features/programming/meld
      # ../features/programming/neovim
      ../features/programming/python
      ../features/programming/vscode
      ../features/security/veracrypt
      ../features/security/yubikey-manager
      # ../features/security/tailscale
      ../features/security/keepassxc
      # ../features/virtual-machine/base
      # ../features/virtual-machine/kubernetes/master
      # ../features/virtual-machine/kubernetes/node
      # ../features/virtual-machine/microvm
      # ../features/virtual-machine/ssh
      ../features/window-manager/alacritty
      ../features/window-manager/xfce
    ];
  };
}
