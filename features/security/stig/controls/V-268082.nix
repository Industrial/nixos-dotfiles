# V-268082 (CAT II) — NixOS must display the Standard Mandatory DoW Notice and Consent Banner
# before granting local or remote access via a command line user logon.
#
# Banner text comes from ../lib/dow-banner.nix, shared with V-268083 (SSH) and V-268084
# (graphical). The three fix texts each repeat the full notice; repeating a legal string three
# times is how one copy drifts, and the shared module's suite asserts every paragraph appears
# verbatim in the benchmark's own fix text.
#
# `full` profile, not base-safe: this prints seven paragraphs of legal notice before every
# console login.
{...}: let
  banner = import ../lib/dow-banner.nix;
in {
  services.getty.helpLine = banner.multiline;
}
