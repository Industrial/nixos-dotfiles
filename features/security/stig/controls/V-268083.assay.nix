# Colocated suite: V-268083 — consent banner on SSH logon.
let
  assay = import ./../../../../common/assay/default.nix;
  banner = import ./../lib/dow-banner.nix;
  mod = import ./V-268083.nix {};
in
  assay.suite "stig-V-268083" {
    usesTheSharedBanner = assay.eq mod.services.openssh.banner banner.multiline;
    # Identical text to the console banner — three controls, one notice.
    matchesConsoleBanner = assay.eq mod.services.openssh.banner (import ./V-268082.nix {}).services.getty.helpLine;
    usesDoWWording = assay.eq (builtins.match ".*Department of Defense.*" mod.services.openssh.banner) null;
  }
