# CLI Desktop Profile
# The command-line features that only pay off with a human at a graphical seat. Split out of
# profiles/base.nix; imported by profiles/desktop.nix.
#
# All four hosts import profiles/desktop.nix today (hosts/*/configuration.nix), so this file
# changes no host's closure — the split is structural. The payoff is gated on a host dropping
# profiles/desktop.nix, at which point this list is exactly what leaves it, and the decision is
# a one-line edit instead of a 54-entry audit.
#
# Every entry carries its reason. If a reason stops being true, the entry moves to cli-core.
{...}: {
  imports = [
    ../features/cli/bluetuith # Bluetooth pairing TUI — radios are paired at the seat they serve.
    ../features/cli/broot # Second TUI file manager; duplicates ranger in cli-core.
    ../features/cli/calcurse # Personal calendar — a headless host has no agenda.
    ../features/cli/fastfetch # neofetch-style banner; the output exists to be looked at.
    ../features/cli/lazysql # Exploratory SQL browsing by hand; a service reaches its database in code.
    ../features/cli/leaves # Disk-usage treemap; duplicates dust in cli-core and needs eyes.
    ../features/cli/ngrok # Exposes a local dev server for a human demo, not fleet traffic.
    ../features/cli/nixos-update-notifier # Its user timer `wants` graphical-session.target.
    ../features/cli/nvtop # GPU process monitor; here the GPU is the display adapter.
    ../features/cli/slumber # Postman-style HTTP requests driven by hand, same case as ngrok.
    ../features/cli/spotify-player # Music player — nobody listens to a server.
    ../features/cli/usbtree # Tree rendering of lsusb's data, for whoever plugged the thing in.
  ];
}
