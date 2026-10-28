# V-268086 (CAT II) — NixOS must initiate a session lock after a 10-minute period of
# inactivity for graphical user logon.
#
# The published fix text is GNOME-specific and partly stale:
#
#   programs.dconf.profiles.user.databases = ... idle-delay = mkUint32 600 ...
#   services.logind.extraConfig = "IdleAction = lock\nIdleActionSec = 600";
#   services.xserver.displayManager.gdm.wayland = true;
#   services.xserver.xautolock = { enable = true; time = 10; locker = loginctl lock-session; };
#
# Problems, in order of severity:
#
#   1. `services.logind.extraConfig` is a RENAMED option (logind.nix line 84). Canonical path
#      is `services.logind.settings.Login.*`.
#   2. The dconf half only binds GNOME sessions. This fleet runs Hyprland, so those keys have
#      no consumer on a workstation — writing them would produce a config that looks compliant
#      and locks nothing.
#   3. xautolock is X11-only and does nothing under a Wayland compositor.
#
# So the requirement is met by the one mechanism that is compositor-independent: logind's own
# idle handling. `IdleAction = lock` plus `IdleActionSec = 600` makes logind lock the session
# after ten minutes regardless of which greeter or compositor is running, which is what the
# requirement actually asks for.
#
# The GNOME dconf keys are also set, because where GDM *is* the greeter (the VM target for
# this profile) the check greps for them. They are inert elsewhere, and inert-by-design is
# acceptable here in a way it was not for V-268165's chcon audit rule — a dconf key for an
# absent session is ignored, whereas an audit watch on an absent path aborts the whole rule
# file.
#
# `full` profile: a forced 10-minute lock is exactly the kind of interruption base-safe
# promises not to introduce.
{lib, ...}: {
  services.logind.settings.Login = {
    IdleAction = "lock";
    IdleActionSec = 600;
  };

  programs.dconf.profiles.user.databases = lib.mkBefore [
    {
      settings."org/gnome/desktop/session".idle-delay = lib.gvariant.mkUint32 600;
      locks = ["org/gnome/desktop/session/idle-delay"];
    }
  ];
}
