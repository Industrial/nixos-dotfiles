# Colocated suite: V-268178 — cached authenticators expire after one day.
#
# The case that matters is an SSSD configuration that exists but caches forever. Asserting
# only that sssd.conf is present would pass exactly the configuration this control forbids.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  control = sssdConfig:
    import ./V-268178.nix {
      lib = nixpkgsLib;
      config.security.stig = {inherit sssdConfig;};
    };

  expiryVerdict = mod: (builtins.elemAt mod.assertions 0).assertion;
  presenceVerdict = mod: (builtins.elemAt mod.assertions 1).assertion;

  unset = control null;
  cachesForever = control "[sssd]\ndomains = example.com\n";
  expiresDaily = control "[sssd]\ndomains = example.com\n\n[pam]\noffline_credentials_expiration = 1\n";
in
  assay.suite "stig-V-268178" {
    # Unset: the presence assertion complains, the expiry one is vacuously satisfied.
    refusesWithoutSssd = assay.eq (presenceVerdict unset) false;
    expiryIsVacuousWithoutSssd = assay.eq (expiryVerdict unset) true;

    # Configured but caching forever — the finding this control exists for.
    refusesIndefiniteCaching = assay.eq (expiryVerdict cachesForever) false;
    messageNamesTheSetting =
      assay.eq (builtins.match ".*offline_credentials_expiration.*" (builtins.head cachesForever.assertions).message != null) true;
    messageRecordsTheEmptyFixText =
      assay.eq (builtins.match ".*never names the setting.*" (builtins.head cachesForever.assertions).message != null) true;
    # And it must not enable SSSD in that state.
    doesNotEnableSssdWhenCachingForever = assay.eq (cachesForever.services.sssd or {}) {};

    acceptsDailyExpiry = assay.eq (expiryVerdict expiresDaily) true;
    enablesSssdWhenCompliant = assay.eq expiresDaily.services.sssd.enable true;
  }
