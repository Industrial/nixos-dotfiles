# Colocated suite for rust/tools/vdiff/default.nix — the buildRustPackage
# derivation of the vdiff closure differ.
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
  assay.suite "vdiff" {
    pnameIsTheCrateName = assay.eq pkg.pname crate.name;
    versionIsTheCrateVersion = assay.eq pkg.version crate.version;

    # buildRustPackage with the dependencies vendored from the checked-in
    # Cargo.lock, so no cargoHash has to be bumped alongside it.
    usesBuildRustPackage = assay.eq (pkg ? cargoDeps && pkg ? cargoBuildType) true;
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;

    # Standalone: its own lockfile and an empty [workspace].
    standaloneWorkspace = assay.eq (manifest.workspace or null) {};

    # One id_effect version per build, pinned exactly; Voltaic pinned past
    # 0.2.0's miscompiles.
    idEffectPinned = assay.eq manifest.dependencies.id_effect "=0.13.0";
    voltaicPinned = assay.eq manifest.build-dependencies.voltaic-driver "=0.2.1";

    # rusqlite's bundled SQLite builds from source: without this the fleet's
    # Nix build fails with `ld: cannot find -lsqlite3` (how vgc broke a deploy).
    vendoredSqlite = assay.eq (pkg.dontCargoUseSystemLibs or false) true;

    # nix-store-core is a path dependency, and the golden cases ship with the
    # source so the package's test run reads them.
    pathDependencyAndFixturesInSource =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["vdiff/Cargo.lock" "nix-store-core/Cargo.toml" "nix-store-core/src/db.vlt" "vdiff/tests/fixtures/synthetic.json"]) [true true true true];
    buildsTheVdiffCrate = assay.eq [pkg.cargoRoot pkg.buildAndTestSubdir] ["vdiff" "vdiff"];

    mainProgram = assay.eq pkg.meta.mainProgram "vdiff";
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
