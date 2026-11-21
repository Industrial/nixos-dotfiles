# Build a nixosConfiguration for a fleet host.
#
# Every host gets the same module set (lib/features.nix `modules`): every catalogued
# feature (features/catalog.nix, each wrapped so it declares `features.<path>.enable`)
# and every profile (profiles/*.nix, each declaring `profiles.<name>.enable`). All of
# it is off by default. hosts/<name>/configuration.nix then says which profiles and
# features that host runs — by option, so a profile's choice can be overridden per
# host with `lib.mkForce false` rather than by editing or commenting out an import.
{inputs}: hostname: let
  inherit (inputs.nixpkgs) lib;
  inherit
    (import ../common/settings.nix {
      inherit hostname;
      # Git commit identity on every host (features/programming/git).
      useremail = "tom.wieland@gmail.com";
    })
    settings
    ;
  features = import ./features.nix {inherit lib;};
in
  lib.nixosSystem {
    inherit (settings) system;
    specialArgs = {inherit inputs settings;};
    modules =
      features.modules
      ++ [
        # The commit this system was built from, so `nixos-version
        # --configuration-revision` can tell which commit a host runs (bin/watch-fleet).
        # comin evaluates `git+file://<checkout>?rev=<commit>`, a clean locked ref, so on
        # a pulled host this is the commit comin fetched. A local build from a dirty tree
        # gets `<rev>-dirty`; an evaluation with no flake `self` (assay suites) "unknown".
        {system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or "unknown";}
        ../hosts/${hostname}/configuration.nix
      ];
  }
