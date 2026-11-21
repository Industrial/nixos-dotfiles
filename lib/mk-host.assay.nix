# Suite for lib/mk-host.nix — the module set every host is built from.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ./features.nix {inherit lib;};
  mimir = import ./mk-host.nix {inputs = nixos.flakeInputs;} "mimir";
  # The same host built from a flake whose `self` is clean or dirty.
  revisionWith = self: (import ./mk-host.nix {inputs = nixos.flakeInputs // {inherit self;};} "mimir").config.system.configurationRevision;
in
  assay.suite "mk-host" {
    # settings.hostname reaches the system.
    hostnameFromSettings = assay.eq mimir.config.networking.hostName "mimir";

    # Fleet hosts commit under the real address, not settings.nix's placeholder.
    realUseremail = assay.eq mimir._module.specialArgs.settings.useremail "tom.wieland@gmail.com";

    # Every catalogued feature is declared on every host, so a host can switch any of
    # them on or off; one not enabled anywhere is declared but false.
    declaresEveryFeature = assay.eq (lib.all (p: lib.hasAttrByPath (features.optionPath p ++ ["enable"]) mimir.config) features.catalog) true;
    gamingOffOnMimir = assay.eq mimir.config.features.games.lutris.enable false;

    # Every host records the commit it was built from (bin/watch-fleet reads it back with
    # `nixos-version --configuration-revision`): self.rev, then self.dirtyRev, then
    # "unknown" when there is no flake self at all.
    revisionFromSelfRev = assay.eq (revisionWith {
      rev = "0123456789abcdef0123456789abcdef01234567";
      dirtyRev = "ignored-dirty";
    }) "0123456789abcdef0123456789abcdef01234567";
    revisionFallsBackToDirtyRev = assay.eq (revisionWith {dirtyRev = "0123456-dirty";}) "0123456-dirty";
    revisionUnknownWithoutSelf = assay.eq mimir.config.system.configurationRevision "unknown";

    # A dependency a feature imports (claude-code's ../lean-ctx) gets its own switch.
    dependencySwitchDeclared = assay.eq (mimir.config.features.ai ? lean-ctx) true;
  }
