# Colocated suite: V-268157 (CAT I) — approved SSH MACs only.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268157.nix {};
  config = fixture.evalWith [{services.openssh.enable = true;} ./V-268157.nix];
  macs = mod.services.openssh.settings.Macs;
in
  assay.suite "stig-V-268157" {
    macs = assay.eq macs ["hmac-sha2-512" "hmac-sha2-256"];
    reachesEvaluatedConfig = assay.eq config.services.openssh.settings.Macs macs;

    allAreSha2 = assay.eq (builtins.all (m: builtins.match "hmac-sha2-(256|512)" m != null) macs) true;
    # No MD5 or SHA-1 MAC may appear.
    noWeakMacs = assay.eq (builtins.filter (m: builtins.match ".*(md5|sha1).*" m != null) macs) [];
  }
