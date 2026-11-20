# Assay: the GNOME workspace launcher (a user unit that opens the day's apps at login).
#
# Claims read the evaluated systemd.user unit; the launcher is a store script, read back
# (IFD is fine in a suite) and matched as text, since the script IS the artifact.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./workspace-setup.nix];};
  unit = cfg.systemd.user.services.gnome-workspace-launcher;
  sc = unit.serviceConfig;
  script = builtins.readFile sc.ExecStart;
  launched =
    map builtins.head (builtins.filter (m: m != null)
      (map (builtins.match "gtk-launch ([^ ]+) &") (map lib.trim (lib.splitString "\n" script))));
in
  assay.suite "workspace-setup" {
    # Started by, and ordered after, the graphical session; a oneshot that stays "active" so
    # it does not re-run on every target re-activation.
    startsWithGraphicalSession = assay.eq unit.wantedBy ["graphical-session.target"];
    orderedAfterGraphicalSession = assay.eq unit.after ["graphical-session.target"];
    isOneshotThatRemains = assay.eq [sc.Type sc.RemainAfterExit] ["oneshot" true];
    boundedStartTimeout = assay.eq sc.TimeoutStartSec "3min";
    runsTheLauncher = assay.eq (lib.hasSuffix "/bin/workspace-launcher" sc.ExecStart) true;

    # org.gnome.Shell on the session bus is the readiness probe; Shell.Eval returns false on
    # GNOME 49+ and must not be used.
    waitsForShellOnSessionBus = assay.eq (lib.hasInfix "busctl --user --timeout 2 status org.gnome.Shell" script) true;
    doesNotProbeWithShellEval = assay.eq (lib.hasInfix "org.gnome.Shell.Eval" script) false;
    givesUpAfterTwoMinutes = assay.eq (lib.hasInfix "deadline=$((SECONDS + 120))" script) true;
    launchesTheWorkspaceApps =
      assay.eq launched
      ["librewolf.desktop" "cursor.desktop" "obsidian.desktop" "spotify.desktop" "discord.desktop" "signal-desktop.desktop"];
  }
