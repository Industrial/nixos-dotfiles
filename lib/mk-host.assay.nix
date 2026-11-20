# Suite for lib/mk-host.nix — the module set every host is built from.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ./features.nix {inherit lib;};
  mimir = import ./mk-host.nix {inputs = nixos.flakeInputs;} "mimir";
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

    # A dependency a feature imports (claude-code's ../lean-ctx) gets its own switch.
    dependencySwitchDeclared = assay.eq (mimir.config.features.ai ? lean-ctx) true;
  }
