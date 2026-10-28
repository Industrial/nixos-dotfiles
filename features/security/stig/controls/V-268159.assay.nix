# Colocated suite: V-268159 (CAT I) — encrypted transport available and constrained.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268159.nix {};
  # The CAT I claim is only meaningful together with the crypto-narrowing controls.
  config = fixture.evalWith [./V-268159.nix ./V-268089.nix ./V-268157.nix];
in
  assay.suite "stig-V-268159" {
    sshdEnabled = assay.eq mod.services.openssh.enable true;

    # Canonical option, not the services.sshd alias the fix text uses.
    usesCanonicalOption = assay.eq (builtins.hasAttr "openssh" mod.services) true;
    reachesEvaluatedConfig = assay.eq config.services.openssh.enable true;

    # Confidentiality and integrity come from these, not from enabling the daemon.
    ciphersConstrained = assay.eq config.services.openssh.settings.Ciphers ["aes256-ctr" "aes192-ctr" "aes128-ctr"];
    macsConstrained = assay.eq config.services.openssh.settings.Macs ["hmac-sha2-512" "hmac-sha2-256"];
  }
