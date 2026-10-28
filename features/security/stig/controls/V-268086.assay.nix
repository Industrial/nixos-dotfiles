# Colocated suite: V-268086 — graphical session locks after 10 minutes idle.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;
  mod = import ./V-268086.nix {lib = nixpkgsLib;};
in
  assay.suite "stig-V-268086" {
    # The compositor-independent mechanism, and the one that actually locks on this fleet.
    logindLocksOnIdle = assay.eq mod.services.logind.settings.Login.IdleAction "lock";
    logindIdleIsTenMinutes = assay.eq mod.services.logind.settings.Login.IdleActionSec 600;

    # Canonical path, not the fix text's renamed services.logind.extraConfig.
    doesNotUseRenamedExtraConfig = assay.eq (mod.services.logind ? extraConfig) false;

    # The GNOME keys are set too, for a GDM target where the check greps for them. They are
    # inert under Hyprland — acceptable here because an unused dconf key is ignored, unlike
    # V-268165's audit watch on a missing path which aborts the entire rule file.
    setsGnomeIdleDelay = assay.eq (builtins.length mod.programs.dconf.profiles.user.databases.content) 1;
    locksTheGnomeKey =
      assay.eq (builtins.head (builtins.head mod.programs.dconf.profiles.user.databases.content).locks)
      "org/gnome/desktop/session/idle-delay";

    # xautolock is deliberately NOT used: it is X11-only and does nothing under Wayland, so
    # enabling it would be compliance theatre.
    doesNotUseXautolock = assay.eq (mod.services ? xserver) false;
  }
