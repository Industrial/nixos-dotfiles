# V-268083 (CAT II) — NixOS must display the Standard Mandatory DoW Notice and Consent Banner
# before granting local or remote access via an SSH logon.
#
# Banner text from ../lib/dow-banner.nix, shared with V-268082 and V-268084.
#
# `full` profile. This one has an operational edge the console banner does not: sshd sends the
# banner BEFORE authentication, so every scripted ssh and every fleet automation run receives
# seven paragraphs on stderr. `bin/fleet` and comin tolerate it, but anything parsing ssh
# output will need to.
{...}: let
  banner = import ../lib/dow-banner.nix;
in {
  services.openssh.banner = banner.multiline;
}
