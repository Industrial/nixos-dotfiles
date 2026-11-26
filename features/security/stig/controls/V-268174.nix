# V-268174 (CAT II) — NixOS must disable account identifiers after 35 days of inactivity.
#
# Fix text:
#
#   environment.etc."/default/useradd".text = lib.mkForce ''
#     INACTIVE=35
#   '';
#
# Two problems. The leading slash renders to /etc//default/useradd, the same slip as the
# pwquality fix texts. And `mkForce` on the whole file discards whatever else nixpkgs puts in
# /etc/default/useradd — the shadow package's defaults for GROUP, HOME and SHELL — so the
# literal fix replaces a config file with a single line.
#
# Written without the leading slash, and keeping those three lines.
#
# It cannot be purely additive, though. nixpkgs (programs/shadow.nix) defines this file's
# `source` directly, as one derivation, so a second plain definition of `text` or `source` is
# a "conflicting definition values" evaluation error on any real host. The earlier version
# of this control set only `text = "INACTIVE=35"` and so did not evaluate outside its own
# suite. One definition has to win, so this one is forced and restates the three lines
# nixpkgs writes, from the same options nixpkgs reads, before adding its own.
#
# INACTIVE applies to accounts created AFTER it is set; it does not retroactively change
# existing accounts, which the check's `useradd -D` reading does not distinguish. Noted for
# the report's justification column.
#
# `full` profile: a seldom-used host disables its own only account after 35 days, which is a
# lockout waiting to happen on a laptop that spends a month in a drawer — exactly what
# happened to huginn and mimir in this fleet.
{
  config,
  lib,
  utils,
  ...
}: {
  environment.etc."default/useradd".text = lib.mkForce ''
    GROUP=100
    HOME=${config.users.defaultUserHome}
    SHELL=${utils.toShellPath config.users.defaultUserShell}
    INACTIVE=35
  '';
}
