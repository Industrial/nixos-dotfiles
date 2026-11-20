# CLI Desktop Profile
# The command-line features that only pay off with a human at a graphical seat. Split out of
# profiles/base.nix; enabled by profiles/desktop.nix.
#
# All four hosts enable profiles/desktop.nix today (hosts/*/configuration.nix), so this file
# changes no host's closure — the split is structural. The payoff is gated on a host dropping
# profiles/desktop.nix, at which point this list is exactly what leaves it, and the decision is
# a one-line edit instead of a 54-entry audit.
#
# Every entry carries its reason. If a reason stops being true, the entry moves to cli-core.
{
  config,
  lib,
  ...
}: {
  options.profiles.cli-desktop.enable = lib.mkEnableOption "the cli-desktop profile";

  config = lib.mkIf config.profiles.cli-desktop.enable {
    features.cli.bluetuith.enable = true; # Bluetooth pairing TUI — radios are paired at the seat they serve.
    features.cli.broot.enable = true; # Second TUI file manager; duplicates ranger in cli-core.
    features.cli.calcurse.enable = true; # Personal calendar — a headless host has no agenda.
    features.cli.fastfetch.enable = true; # neofetch-style banner; the output exists to be looked at.
    features.cli.lazysql.enable = true; # Exploratory SQL browsing by hand; a service reaches its database in code.
    features.cli.leaves.enable = true; # Disk-usage treemap; duplicates dust in cli-core and needs eyes.
    features.cli.ngrok.enable = true; # Exposes a local dev server for a human demo, not fleet traffic.
    features.cli.nixos-update-notifier.enable = true; # Its user timer `wants` graphical-session.target.
    features.cli.nvtop.enable = true; # GPU process monitor; here the GPU is the display adapter.
    features.cli.slumber.enable = true; # Postman-style HTTP requests driven by hand, same case as ngrok.
    features.cli.spotify-player.enable = true; # Music player — nobody listens to a server.
    features.cli.usbtree.enable = true; # Tree rendering of lsusb's data, for whoever plugged the thing in.
  };
}
