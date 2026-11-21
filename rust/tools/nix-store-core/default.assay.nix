# Colocated suite for rust/tools/nix-store-core/default.nix — the buildRustPackage
# derivation of the store primitives library (its test run).
#
# Built with callPackage from the pinned nixpkgs. Claims read the derivation's
# attributes; Cargo.toml is TOML and is parsed, so the Nix identity is checked
# against the crate's own.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  pkg = pkgs.callPackage ./default.nix {};
  manifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
  crate = manifest.package;
in
  assay.suite "nix-store-core" {
    pnameIsTheCrateName = assay.eq pkg.pname crate.name;
    versionIsTheCrateVersion = assay.eq pkg.version crate.version;

    # buildRustPackage with the dependencies vendored from the checked-in
    # Cargo.lock, so no cargoHash has to be bumped alongside it.
    usesBuildRustPackage = assay.eq (pkg ? cargoDeps && pkg ? cargoBuildType) true;
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;

    # Standalone: its own lockfile and an empty [workspace], so it never joins
    # rust/Cargo.toml's workspace or its lockfile.
    standaloneWorkspace = assay.eq (manifest.workspace or null) {};

    # One id_effect version per build, pinned exactly; Voltaic pinned past
    # 0.2.0's miscompiles.
    idEffectPinned = assay.eq manifest.dependencies.id_effect "=0.13.0";
    voltaicPinned = assay.eq manifest.build-dependencies.voltaic-driver "=0.2.1";

    # The golden tests read tests/fixtures in checkPhase, so the source carries it.
    fixturesInSource = assay.eq (map (f: builtins.pathExists "${pkg.src}/tests/fixtures/${f}") ["paths.json" "drvs.json" "nar-tree.json"]) [true true true];

    # A library: no program to name.
    noMainProgram = assay.eq (pkg.meta ? mainProgram) false;
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
