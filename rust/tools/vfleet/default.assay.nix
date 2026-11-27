# Colocated suite for rust/tools/vfleet: its package, and the seam between the Voltaic
# inventory and NixOS (common/fleet.nix and features/catalog.nix read the JSON it
# generates). Evaluated, not built; the drift test itself is vfleet's cargo test.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  pkg = pkgs.callPackage ./default.nix {};
  manifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
  fleetJson = builtins.fromJSON (builtins.readFile ../../../common/fleet.json);
  catalogJson = builtins.fromJSON (builtins.readFile ../../../features/catalog.json);
  fleet = import ../../../common/fleet.nix;
  catalog = import ../../../features/catalog.nix;
in
  assay.suite "vfleet" {
    pnameIsTheCrateName = assay.eq pkg.pname manifest.package.name;
    versionIsTheCrateVersion = assay.eq pkg.version manifest.package.version;
    mainProgram = assay.eq pkg.meta.mainProgram "vfleet";
    standaloneWorkspace = assay.eq (manifest.workspace or null) {};
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;
    idEffectPinned = assay.eq [manifest.dependencies.id_effect manifest.dependencies.id_effect_cli] ["=0.13.0" "=0.13.0"];
    voltaicPinned = assay.eq [manifest.build-dependencies.voltaic-driver manifest.build-dependencies.voltaic-diag] ["=0.3.0" "=0.3.0"];

    # The sandbox build carries the generated files, so the drift test runs there too.
    sourceCarriesTheGeneratedJson =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["common/fleet.json" "features/catalog.json" "rust/tools/vfleet/src/inventory.vlt"]) [true true true];

    # NixOS reads the JSON as it is: the inventory's hosts and orders, and one catalog
    # path per entry, in order.
    fleetHostsAreTheJson = assay.eq fleet.hosts fleetJson.hosts;
    fleetOrderIsTheJson = assay.eq [fleet.order fleet.cachePort] [fleetJson.order fleetJson.cachePort];
    catalogIsTheJson = assay.eq (map toString catalog) (map (p: toString ../../../features + "/${p}") catalogJson);
  }
