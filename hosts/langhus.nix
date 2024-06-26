{inputs, ...}: {
  langhus = let
    settings = {
      hostname = "langhus";
      stateVersion = "24.05";
      system = "x86_64-linux";
      hostPlatform = {
        system = "x86_64-linux";
      };
      userdir = "/home/tom";
      useremail = "tom.wieland@gmail.com";
      userfullname = "Tom Wieland";
      username = "tom";
    };
  in
    inputs.nixpkgs.lib.nixosSystem {
      system = settings.system;
      specialArgs = {
        inherit inputs;
        settings = settings;
      };
      modules = [
        ../features/cli/ansifilter
        ../features/cli/appimage-run
        ../features/cli/aria2
        ../features/cli/bat
        ../features/cli/btop
        ../features/cli/c
        ../features/cli/cheatsheet
        ../features/cli/direnv
        ../features/cli/du
        ../features/cli/dust
        ../features/cli/e2fsprogs
        ../features/cli/eza
        ../features/cli/fd
        ../features/cli/fh
        ../features/cli/fish
        ../features/cli/fzf
        ../features/cli/g
        ../features/cli/gh
        ../features/cli/killall
        ../features/cli/l
        ../features/cli/lazygit
        ../features/cli/ll
        ../features/cli/neofetch
        ../features/cli/p7zip
        ../features/cli/ranger
        ../features/cli/ripgrep
        ../features/cli/starship
        ../features/cli/unrar
        ../features/cli/unzip
        ../features/cli/zellij
        ../features/communication/discord
        ../features/crypto/monero
        ../features/filesystems/gparted
        ../features/games/lutris
        ../features/games/path-of-building
        ../features/games/steam
        ../features/hardware/zsa-keyboard
        ../features/media/eog
        ../features/media/invidious
        ../features/media/lxqt-pavucontrol-qt
        ../features/media/lxqt-screengrab
        ../features/media/mpv
        ../features/media/obs-studio
        ../features/media/okular
        ../features/media/spotify
        ../features/media/vlc
        ../features/monitoring/grafana
        ../features/monitoring/homepage-dashboard
        ../features/monitoring/lxqt-qps
        ../features/monitoring/prometheus
        ../features/network/chromium
        ../features/network/filezilla
        ../features/network/firefox
        ../features/network/i2pd
        ../features/network/nginx
        ../features/network/syncthing
        ../features/network/tor
        ../features/network/tor-browser
        ../features/network/transmission
        ../features/nix
        #../features/nix/nix-daemon
        ../features/nix/nix-unit
        ../features/nix/nixpkgs
        ../features/nixos/bluetooth
        ../features/nixos/boot
        ../features/nixos/console
        ../features/nixos/docker
        ../features/nixos/fonts
        ../features/nixos/graphics
        ../features/nixos/i18n
        ../features/nixos/networking
        ../features/nixos/security
        ../features/nixos/sound
        ../features/nixos/system
        ../features/nixos/time
        ../features/nixos/users
        ../features/nixos/window-manager
        ../features/office/cryptpad
        ../features/office/evince
        ../features/office/lxqt-archiver
        ../features/office/lxqt-pcmanfm-qt
        ../features/office/obsidian
        ../features/programming/android-tools
        ../features/programming/bun
        ../features/programming/deno
        ../features/programming/docker-compose
        ../features/programming/edgedb
        ../features/programming/git
        ../features/programming/gitkraken
        ../features/programming/glogg
        ../features/programming/insomnia
        ../features/programming/local-ai
        ../features/programming/meld
        #../features/programming/neovim
        ../features/programming/nixd
        ../features/programming/nodejs
        ../features/programming/ollama
        ../features/programming/sqlite
        ../features/programming/vscode
        ../features/security/bitwarden
        ../features/security/vaultwarden
        ../features/security/veracrypt
        ../features/security/yubikey-manager
        ../features/window-manager/alacritty
        #../features/window-manager/dwm
        ../features/window-manager/hyper
        ../features/window-manager/slock
        ../features/window-manager/xfce
        #../features/window-manager/xmonad

        inputs.stylix.nixosModules.stylix
        ../features/window-manager/stylix
      ];
    };
}
