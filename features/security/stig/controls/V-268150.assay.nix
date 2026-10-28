# Colocated suite: V-268150 — timesyncd polls at least once a minute.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268150.nix {};
  config = fixture.evalWith [./V-268151.nix ./V-268150.nix];
  value = mod.services.timesyncd.settings.Time.PollIntervalMaxSec;
in
  assay.suite "stig-V-268150" {
    pollIntervalMax = assay.eq value 60;
    reachesEvaluatedConfig = assay.eq config.services.timesyncd.settings.Time.PollIntervalMaxSec 60;

    # Declared through settings.Time, because services.timesyncd.extraConfig — what the fix
    # text asks for — has been removed from nixpkgs and now fails evaluation outright.
    usesStructuredSettings = assay.eq (mod.services.timesyncd ? settings) true;
    doesNotUseRemovedExtraConfig = assay.eq (mod.services.timesyncd ? extraConfig) false;

    # The check is an inequality (> 60 is a finding), so 60 is the ceiling.
    isAtOrBelowCeiling = assay.eq (value <= 60) true;

    # Composes with V-268151 — a poll interval is meaningless if the service is off.
    timesyncdIsEnabled = assay.eq config.services.timesyncd.enable true;
  }
