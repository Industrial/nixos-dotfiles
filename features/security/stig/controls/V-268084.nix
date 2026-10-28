# V-268084 (CAT II) — NixOS must display the Standard Mandatory DoW Notice and Consent Banner
# before granting local or remote access via a graphical user logon.
#
# The fix text uses `services.xserver.displayManager.gdm.banner`, which has been RENAMED to
# `services.displayManager.gdm.banner` (gdm.nix line 101). Canonical path used here.
#
# Two things make this control awkward on this fleet, both for the report's justification
# column rather than for silent deviation:
#
#   1. The option is GDM-specific. This fleet runs Hyprland with no GDM, so the setting has no
#      consumer on a workstation — the control is only satisfiable where GDM is the greeter.
#      `profiles/full.nix` therefore enables GDM for the VM target, which is the only place
#      this control can be demonstrated at all.
#   2. The option takes ONE string with escaped newlines, not a block, which is why
#      ../lib/dow-banner.nix exposes `singleLine` alongside `multiline`.
{...}: let
  banner = import ../lib/dow-banner.nix;
in {
  services.displayManager.gdm.banner = banner.singleLine;
}
