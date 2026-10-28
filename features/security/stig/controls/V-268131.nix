# V-268131 (CAT I) — NixOS must not have the telnet package installed.
#
# Fix text: remove any reference to pkgs.libtelnet, pkgs.busybox or pkgs.inetutils from
# environment.systemPackages.
# Check: `whereis telnet` must return no path.
#
# This is the rare control satisfied by an absence, so there is nothing to set. Setting
# nothing is also unverifiable and silently regresses the moment someone adds inetutils for
# its ftp or whois, which is exactly how CAT I findings appear. So the control is implemented
# as an eval-time assertion: adding a telnet-bearing package to systemPackages fails the
# build rather than quietly failing an audit later.
#
# Verified at implementation time: nothing in profiles/, hosts/, features/, common/ or
# installer/ referenced any of these packages.
{
  config,
  lib,
  ...
}: let
  # inetutils and busybox both ship a telnet client; libtelnet is the library.
  forbidden = ["libtelnet" "inetutils" "busybox" "telnet"];

  packageName = p: p.pname or p.name or "";
  offenders =
    lib.unique
    (lib.filter (n: n != "" && lib.any (f: lib.hasInfix f n) forbidden)
      (map packageName config.environment.systemPackages));
in {
  assertions = [
    {
      assertion = offenders == [];
      message = ''
        V-268131 (CAT I): a telnet-bearing package is in environment.systemPackages: ${lib.concatStringsSep ", " offenders}.
        telnet transmits credentials in the clear. Remove it, or if the package is needed for
        something other than telnet, exclude the control with a written justification:
          security.stig.exclude."V-268131" = "<why this host must carry it>";
      '';
    }
  ];
}
