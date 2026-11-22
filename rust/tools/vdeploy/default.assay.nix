# Colocated suite for rust/tools/vdeploy/default.nix — the buildRustPackage derivation
# of the vdeploy deploy agent (observe mode).
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
  assay.suite "vdeploy" {
    pnameIsTheCrateName = assay.eq pkg.pname crate.name;
    versionIsTheCrateVersion = assay.eq pkg.version crate.version;

    # buildRustPackage with the dependencies vendored from the checked-in
    # Cargo.lock, so no cargoHash has to be bumped alongside it.
    usesBuildRustPackage = assay.eq (pkg ? cargoDeps && pkg ? cargoBuildType) true;
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;

    # Standalone: its own lockfile and an empty [workspace].
    standaloneWorkspace = assay.eq (manifest.workspace or null) {};

    # One id_effect version per build, pinned exactly; Voltaic pinned past
    # 0.2.0's miscompiles; vdiff and nix-store-core by path.
    idEffectPinned = assay.eq [manifest.dependencies.id_effect manifest.dependencies.id_effect_cli] ["=0.13.0" "=0.13.0"];
    voltaicPinned = assay.eq [manifest.build-dependencies.voltaic-driver manifest.build-dependencies.voltaic-diag] ["=0.3.0" "=0.3.0"];
    vdiffByPath = assay.eq manifest.dependencies.vdiff {path = "../vdiff";};
    nixStoreCoreByPath = assay.eq manifest.dependencies.nix-store-core {path = "../nix-store-core";};

    # rusqlite's bundled SQLite builds from its own sources; without this the
    # cargoUseSystemLibs hook links a libsqlite3 that is not there.
    vendoredSqlite = assay.eq (pkg.dontCargoUseSystemLibs or false) true;

    # The source and dotfiles tests run git in the sandbox.
    testsHaveGit = assay.eq (builtins.any (d: (d.pname or "") == "git") ((pkg.nativeCheckInputs or []) ++ (pkg.nativeBuildInputs or []))) true;

    # GH-221: the signature tests run gpgv on the pinned key and a real signed commit.
    testsHaveGnupg = assay.eq (builtins.any (d: lib.hasPrefix "gnupg" (d.pname or d.name or "")) ((pkg.nativeCheckInputs or []) ++ (pkg.nativeBuildInputs or []))) true;
    signatureDataInSource =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/vdeploy/${f}") ["keys/github-web-flow.asc" "testdata/signed-commit" "testdata/web-flow-2017.asc" "src/signature.vlt"]) [true true true true];

    # The source is rooted at rust/tools, carries all three crates, and the build runs in this one.
    pathDependenciesInSource =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/${f}") ["vdeploy/Cargo.lock" "vdeploy/src/agent.vlt" "vdiff/src/report.vlt" "nix-store-core/Cargo.toml" "nix-store-core/src/db.vlt"]) [true true true true true];
    buildsTheVdeployCrate = assay.eq [pkg.cargoRoot pkg.buildAndTestSubdir] ["vdeploy" "vdeploy"];

    mainProgram = assay.eq pkg.meta.mainProgram "vdeploy";
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
