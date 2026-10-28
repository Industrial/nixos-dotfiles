# Colocated suite: V-268149 — authoritative time servers.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268149.nix {};
in
  assay.suite "stig-V-268149" {
    usesUsnoServers = assay.eq mod.networking.timeServers [
      "tick.usnogps.navy.mil"
      "tock.usnogps.navy.mil"
    ];
    twoServersForRedundancy = assay.eq (builtins.length mod.networking.timeServers) 2;
    bothAreUsno = assay.eq (builtins.all (s: builtins.match ".*usnogps\\.navy\\.mil" s != null) mod.networking.timeServers) true;

    # This REPLACES the nixpkgs NTP pool rather than adding to it, which is why applying it
    # outside a DoD network leaves the host with no reachable time source. Pinned so the
    # consequence stays visible.
    replacesTheDefaultPool =
      assay.eq (mod.networking.timeServers == (fixture.evalWith []).networking.timeServers) false;
  }
