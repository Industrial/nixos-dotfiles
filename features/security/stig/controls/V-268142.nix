# V-268142 (CAT II) — NixOS must terminate all SSH connections after 10 minutes of becoming
# unresponsive.
#
# Fix text uses `services.openssh.extraConfig` with a raw `ClientAliveInterval 600` line.
# `services.openssh.settings` is a freeform submodule on current nixpkgs, so the setting can be
# declared as data instead of as an unparsed config fragment — which matters because the
# neighbouring V-268143 sets ClientAliveCountMax, and two modules appending to `extraConfig`
# gives an opaque blob where two settings entries give a merged attrset the module system can
# reason about.
#
# 600 seconds with V-268143's CountMax of 1 is the "10 minutes" in the requirement.
{...}: {
  services.openssh.settings.ClientAliveInterval = 600;
}
