# CLI Core Profile
# The command-line features a host needs with nobody sitting at it: shell, search, git,
# multiplexer, nix tooling, documentation, archives, system inspection, networking diagnostics.
# Split out of profiles/base.nix, which enables it, so every host still carries exactly this set.
#
# Membership test: would this tool earn its place on a machine reached only over ssh? If the
# answer is "only if someone is looking at a screen", it belongs in profiles/cli-desktop.nix.
{
  config,
  lib,
  ...
}: {
  options.profiles.cli-core.enable = lib.mkEnableOption "the cli-core profile";

  config = lib.mkIf config.profiles.cli-core.enable {
    # Shell and Prompt
    features.cli.atuin.enable = true;
    features.cli.carapace.enable = true;
    features.cli.direnv.enable = true;
    features.cli.fish.enable = true;
    features.cli.nushell.enable = true;
    features.cli.nushell-plugins.enable = true;
    features.cli.shell-init.enable = true;
    features.cli.starship.enable = true;
    features.cli.zoxide.enable = true;

    # Multiplexer
    features.cli.zellij.enable = true;

    # Shell Ergonomics — one-letter wrappers over the tools in the sections below
    features.cli.c.enable = true;
    features.cli.g.enable = true;
    features.cli.l.enable = true;
    features.cli.ll.enable = true;
    features.cli.p.enable = true;

    # Documentation and Help — the answer to "how do I run this" without a browser
    features.cli.navi.enable = true;

    # Files, Listing, Search and Text
    features.cli.bat.enable = true;
    features.cli.eza.enable = true;
    features.cli.fd.enable = true;
    features.cli.fzf.enable = true;
    features.cli.jq.enable = true;
    features.cli.ranger.enable = true;
    features.cli.ripgrep.enable = true;
    features.cli.television.enable = true;
    features.cli.tokei.enable = true;
    features.cli.yazi.enable = true;

    # Git
    features.cli.delta.enable = true;
    features.cli.difftastic.enable = true;
    features.cli.gix.enable = true;
    features.cli.lazygit.enable = true;

    # Nix Tooling
    features.cli.assay.enable = true;
    features.cli.nh.enable = true;
    features.cli.nix-index.enable = true;
    features.cli.nix-output-monitor.enable = true;
    features.cli.nix-tree.enable = true;
    features.cli.nixdrv.enable = true;
    features.cli.nixfetch.enable = true;
    features.cli.nixq.enable = true;
    features.cli.nixstore.enable = true;
    features.cli.nvd.enable = true;

    # Archives
    features.cli.p7zip.enable = true;
    features.cli.unrar.enable = true;
    features.cli.unzip.enable = true;

    # System Inspection
    features.cli.btop.enable = true;
    features.cli.dust.enable = true;
    features.cli.dysk.enable = true;
    features.cli.hyperfine.enable = true;
    features.cli.killall.enable = true;
    features.cli.lnav.enable = true;
    features.cli.lsof.enable = true;
    features.cli.lsusb.enable = true;
    features.cli.oomkiller.enable = true;
    features.cli.procs.enable = true;

    # Networking Diagnostics
    features.cli.bandwhich.enable = true;
    features.cli.gping.enable = true;
    features.cli.nettools.enable = true;

    # Keys and Secrets
    features.cli.create-ssh-key.enable = true;
    features.cli.gpg.enable = true;
  };
}
