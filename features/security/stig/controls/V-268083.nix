# V-268083 (CAT II) — NixOS must display the Standard Mandatory DoW Notice and Consent Banner
# before granting local or remote access via an SSH logon.
#
# Banner text from ../lib/dow-banner.nix, shared with V-268082 and V-268084.
#
# `full` profile. This one has an operational edge the console banner does not: sshd sends the
# banner BEFORE authentication, so every scripted ssh and every fleet automation run receives
# seven paragraphs on stderr. `bin/fleet` and comin tolerate it, but anything parsing ssh
# output will need to.
#
# The fix text sets `services.openssh.banner` to the notice itself. nixpkgs has removed that
# option in favour of `services.openssh.settings.Banner`, which takes the PATH of the file
# sshd sends, so the text is written to /etc/ssh/banner and the setting points at it. Setting
# the removed option is an evaluation error on a real host, which is how this was found: the
# control had only ever been read as an attrset by its suite.
{...}: let
  banner = import ../lib/dow-banner.nix;
in {
  environment.etc."ssh/banner".text = banner.multiline;
  services.openssh.settings.Banner = "/etc/ssh/banner";
}
