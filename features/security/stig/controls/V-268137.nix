# V-268137 (CAT II) — NixOS must not allow direct login to the root account via SSH.
#
# Fix text: services.openssh.permitRootLogin = "no";
#
# That name resolves only through a mkRenamedOptionModule alias (sshd.nix line 203). Canonical
# option is `services.openssh.settings.PermitRootLogin`.
#
# Already set to "no" by features/network/ssh. Declared here so the control is provable from
# this module set; identical values merge without conflict.
{...}: {
  services.openssh.settings.PermitRootLogin = "no";
}
