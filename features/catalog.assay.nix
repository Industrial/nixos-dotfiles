# Suite for features/catalog.nix — the list every host's switches are declared from.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ../lib/features.nix {inherit lib;};
  names = map (p: lib.concatStringsSep "." (features.namePath p)) features.catalog;
  enabledSomewhere = lib.unique (lib.concatMap (h:
    features.enabledFeatures (features.evalSelection {
      modules = [
        (../hosts + "/${h}/configuration.nix")
        {disabledModules = map (f: ../hosts + "/${h}/${f}") ["disko.nix" "filesystems.nix" "hardware.nix"];}
      ];
    }))
  (import ../common/fleet.nix).names);
in
  assay.suite "catalog" {
    everyEntryExists = assay.eq (lib.filter (p: !builtins.pathExists p) features.catalog) [];

    # Two entries mapping to one option name would declare it twice.
    namesUnique = assay.eq (lib.length names) (lib.length (lib.unique names));

    # Parked entries cost every host an evaluation. Only creative's three may be listed
    # without a host enabling them — profiles/creative.nix is commented out everywhere —
    # and nvd, kept as vdiff's one-option rollback (GH-153, profiles/cli-core.assay.nix).
    onlyCreativeParked = assay.eq (lib.filter (n: !builtins.elem n enabledSomewhere) names) ["cli.nvd" "creative.gimp" "creative.obs-studio" "creative.openpencil"];
  }
