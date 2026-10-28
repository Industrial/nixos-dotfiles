# Colocated suite: V-268141 — IPv4 TCP syncookies.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268141.nix {};
in
  assay.suite "stig-V-268141" {
    # The check is an equality test against 1. Do not "improve" this value.
    syncookies = assay.eq mod.boot.kernel.sysctl."net.ipv4.tcp_syncookies" 1;
  }
