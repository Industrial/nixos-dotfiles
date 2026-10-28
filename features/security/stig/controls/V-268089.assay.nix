# Colocated suite: V-268089 (CAT I) — approved SSH ciphers only.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268089.nix {};
  config = fixture.evalWith [{services.openssh.enable = true;} ./V-268089.nix];
  ciphers = mod.services.openssh.settings.Ciphers;
in
  assay.suite "stig-V-268089" {
    ciphers = assay.eq ciphers [
      "aes256-ctr"
      "aes192-ctr"
      "aes128-ctr"
    ];

    # The published fix text's `setting` typo would have created a dead attribute instead of
    # configuring sshd. Assert the value lands on the real option.
    reachesEvaluatedConfig = assay.eq config.services.openssh.settings.Ciphers ciphers;

    # Every entry is counter-mode AES; a CBC cipher slipping in is the regression that matters.
    allAreCounterModeAes = assay.eq (builtins.all (c: builtins.match "aes[0-9]+-ctr" c != null) ciphers) true;
    noCbcCiphers = assay.eq (builtins.filter (c: builtins.match ".*-cbc" c != null) ciphers) [];
  }
