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
        # What features/nixos/networking sets from settings.hostname on a real host; the
        # base profile's vpush switch reads it (fleet.pushesToCache).
        {networking.hostName = h;}
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
    # nvd, kept as vdiff's one-option rollback (GH-153, profiles/cli-core.assay.nix),
    # nix-output-monitor, vmon's (GH-181, the same suite), and nix-tree, vwhy's (GH-182).
    # nh is retired by vswitch (GH-241) and is not a rollback (vswitch's lands on
    # nixos-rebuild); it stays parked so a host can still opt in.
    # virtualisation.microvm-host is switched on by ai.agent-vm, which imports it (#353); a
    # selection-only evaluation does not see that.
    onlyCreativeParked = assay.eq (lib.filter (n: !builtins.elem n enabledSomewhere) names) ["cli.nh" "cli.nix-output-monitor" "cli.nix-tree" "cli.nvd" "creative.gimp" "creative.obs-studio" "creative.openpencil" "virtualisation.microvm-host"];
  }
