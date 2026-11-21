# Feature catalog — every feature a host can switch on.
#
# lib/mk-host.nix wraps each entry with lib/features.nix and imports the lot into
# every host, which declares `features.<category>.<name>.enable` (default false)
# for each. Profiles and hosts then turn features on by option instead of by
# import, and turn them off with `lib.mkForce false` instead of commenting
# lines out.
#
# Option name = path below features/, minus `.nix` / `/default.nix`:
#   ./fleet/comin.nix            -> features.fleet.comin.enable
#   ./nixos/graphics/amd.nix     -> features.nixos.graphics.amd.enable
#
# Features that another feature imports (claude-code's ../lean-ctx, remote-access's
# ../network/ssh) are reached through that import and need no entry here; enabling
# the parent enables them with mkDefault.
#
# Adding a feature: add its path here, then enable it from a profile or host.
# Features left out (openhands, mullvad, the mimir media stack, ...) are not
# evaluated on any host — their enables in hosts/ and profiles/ stay commented
# out until they are listed here.
[
  # ai
  ./ai/claude-code
  ./ai/paseo

  # cli
  ./cli/assay
  ./cli/atuin
  ./cli/bandwhich
  ./cli/bat
  ./cli/bluetuith
  ./cli/broot
  ./cli/btop
  ./cli/c
  ./cli/calcurse
  ./cli/carapace
  ./cli/create-ssh-key
  ./cli/delta
  ./cli/difftastic
  ./cli/direnv
  ./cli/dust
  ./cli/dysk
  ./cli/eza
  ./cli/fastfetch
  ./cli/fd
  ./cli/fish
  ./cli/fzf
  ./cli/g
  ./cli/gix
  ./cli/gpg
  ./cli/gping
  ./cli/hyperfine
  ./cli/jq
  ./cli/killall
  ./cli/l
  ./cli/lazygit
  ./cli/lazysql
  ./cli/leaves
  ./cli/ll
  ./cli/lnav
  ./cli/lowprio
  ./cli/lsof
  ./cli/lsusb
  ./cli/navi
  ./cli/nettools
  ./cli/ngrok
  ./cli/nh
  ./cli/nix-index
  ./cli/nix-output-monitor
  ./cli/nix-tree
  ./cli/nixdrv
  ./cli/nixfetch
  ./cli/nixos-update-notifier
  ./cli/nixq
  ./cli/nixstore
  ./cli/nushell
  ./cli/nushell-plugins
  ./cli/nvd
  ./cli/nvtop
  ./cli/oomkiller
  ./cli/p
  ./cli/p7zip
  ./cli/procs
  ./cli/ranger
  ./cli/ripgrep
  ./cli/shell-init
  ./cli/slumber
  ./cli/spotify-player
  ./cli/starship
  ./cli/television
  ./cli/tokei
  ./cli/unrar
  ./cli/unzip
  ./cli/usbtree
  ./cli/vbump
  ./cli/vdiff
  ./cli/vmon
  ./cli/yazi
  ./cli/zellij
  ./cli/zoxide

  # communication
  ./communication/discord
  ./communication/signal-desktop

  # creative
  ./creative/gimp
  ./creative/obs-studio
  ./creative/openpencil

  # desktop
  ./desktop/claude-desktop

  # finance
  ./finance/tws

  # fleet
  ./fleet/comin.nix
  ./fleet/nix-remote-builder-client.nix
  ./fleet/nix-remote-builder-server.nix
  ./fleet/remote-access.nix
  ./fleet/remote-desktop-relay.nix
  ./fleet/vbuild.nix

  # games
  ./games/appimage
  ./games/awakened-poe-trade
  ./games/exiled-exchange-2
  ./games/lutris
  ./games/path-of-building
  ./games/wow-classic
  ./games/wowup

  # media
  ./media/calibre
  ./media/qbittorrent
  ./media/spotify
  ./media/vlc

  # monitoring
  ./monitoring/grafana
  ./monitoring/homepage-dashboard
  ./monitoring/prometheus
  ./monitoring/prometheus-exporter

  # network
  ./network/chromium
  ./network/firefox
  ./network/searx

  # nix
  ./nix/vcache
  ./nix/vcache/client.nix
  ./nix/vdaemon-proxy
  ./nix/vverify
  ./nix/vpush

  # nixos
  ./nixos
  ./nixos/auto-update
  ./nixos/bluetooth
  ./nixos/boot
  ./nixos/docker
  ./nixos/fonts
  ./nixos/graphics
  ./nixos/graphics/amd.nix
  ./nixos/graphics/intel.nix
  ./nixos/networking
  ./nixos/networking/dns.nix
  ./nixos/networking/firewall.nix
  ./nixos/security/no-defaults
  ./nixos/security/sudo
  ./nixos/sound
  ./nixos/systemd
  ./nixos/users
  ./nixos/vgc
  ./nixos/vopt
  ./nixos/window-manager

  # performance
  ./performance/environment
  ./performance/filesystems
  ./performance/hardware
  ./performance/memory

  # programming
  ./programming/cursor
  ./programming/devenv
  ./programming/docker-compose
  ./programming/emerald
  ./programming/git
  ./programming/gitkraken
  ./programming/helix
  ./programming/neovim
  ./programming/openidea
  ./programming/voltaic
  ./programming/vscodium
  ./programming/zed

  # security
  ./security/apparmor
  ./security/keepassxc
  ./security/pam
  ./security/stig
  ./security/stig/profiles/base-safe.nix
  ./security/stig/profiles/external-evidence.nix
  ./security/veracrypt
  ./security/yubikey

  # storage
  ./storage/nfs-client
  ./storage/nfs-server
  ./storage/qdirstat

  # window-manager
  ./window-manager/alacritty
  ./window-manager/ghostty
  ./window-manager/gnome
  ./window-manager/hyprland
  ./window-manager/stylix
  ./window-manager/xclip
  ./window-manager/xfce-screenshooter
  ./window-manager/xsel
]
