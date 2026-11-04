# CLI Core Profile
# The command-line features a host needs with nobody sitting at it: shell, search, git,
# multiplexer, nix tooling, documentation, archives, system inspection, networking diagnostics.
# Split out of profiles/base.nix, which imports it, so every host still carries exactly this set.
#
# Membership test: would this tool earn its place on a machine reached only over ssh? If the
# answer is "only if someone is looking at a screen", it belongs in profiles/cli-desktop.nix.
{...}: {
  imports = [
    # Shell and Prompt
    ../features/cli/atuin
    ../features/cli/carapace
    ../features/cli/direnv
    ../features/cli/fish
    ../features/cli/nushell
    ../features/cli/nushell-plugins
    ../features/cli/shell-init
    ../features/cli/starship
    ../features/cli/zoxide

    # Multiplexer
    ../features/cli/zellij

    # Shell Ergonomics — one-letter wrappers over the tools in the sections below
    ../features/cli/c
    ../features/cli/cheatsheet
    ../features/cli/du
    ../features/cli/g
    ../features/cli/l
    ../features/cli/ll
    ../features/cli/p

    # Documentation and Help — the answer to "how do I run this" without a browser
    ../features/cli/navi
    ../features/cli/tealdeer

    # Files, Listing, Search and Text
    ../features/cli/bat
    ../features/cli/eza
    ../features/cli/fd
    ../features/cli/fzf
    ../features/cli/jq
    ../features/cli/ranger
    ../features/cli/ripgrep
    ../features/cli/television
    ../features/cli/tokei
    ../features/cli/yazi

    # Git
    ../features/cli/delta
    ../features/cli/difftastic
    ../features/cli/gix
    ../features/cli/lazygit

    # Nix Tooling
    ../features/cli/assay
    ../features/cli/nh
    ../features/cli/nix-index
    ../features/cli/nix-output-monitor
    ../features/cli/nix-tree
    ../features/cli/nixdrv
    ../features/cli/nixfetch
    ../features/cli/nixq
    ../features/cli/nixstore
    ../features/cli/nvd

    # Archives
    ../features/cli/p7zip
    ../features/cli/unrar
    ../features/cli/unzip

    # System Inspection
    ../features/cli/btop
    ../features/cli/dust
    ../features/cli/dysk
    ../features/cli/hyperfine
    ../features/cli/killall
    ../features/cli/lnav
    ../features/cli/lsof
    ../features/cli/lsusb
    ../features/cli/oomkiller
    ../features/cli/procs

    # Networking Diagnostics
    ../features/cli/bandwhich
    ../features/cli/gping
    ../features/cli/nettools

    # Keys and Secrets
    ../features/cli/create-ssh-key
    ../features/cli/gpg
  ];
}
