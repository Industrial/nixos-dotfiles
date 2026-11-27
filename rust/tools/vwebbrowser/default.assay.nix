# Colocated suite for rust/tools/vwebbrowser/default.nix: the buildRustPackage
# of the WebKitGTK browser. Evaluated, not built; Cargo.toml is parsed so the
# package is checked against the crate's own identity and pins.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  pkg = pkgs.callPackage ./default.nix {};
  manifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
  names = map lib.getName;
in
  assay.suite "vwebbrowser-package" {
    nameIsTheCrateName = assay.eq pkg.pname manifest.package.name;
    versionIsTheCrateVersion = assay.eq pkg.version manifest.package.version;
    mainProgramIsVwebbrowser = assay.eq pkg.meta.mainProgram "vwebbrowser";

    # Voltaic and id_effect are pinned exactly: Voltaic's surface still moves
    # between minors, and two id_effect versions' types do not unify.
    voltaicPinnedExactly =
      assay.eq [manifest.build-dependencies.voltaic-driver manifest.build-dependencies.voltaic-diag] ["=0.3.0" "=0.3.0"];
    idEffectPinnedExactly =
      assay.eq [manifest.dependencies.id_effect manifest.dependencies.id_effect_tokio manifest.dependencies.id_effect_cli] ["=0.13.0" "=0.13.0" "=0.13.0"];

    # Standalone crate: its own lockfile, never a member of rust/Cargo.toml.
    isStandalone = assay.eq (manifest.workspace or null) {};
    usesBuildRustPackage = assay.eq (pkg ? cargoDeps && pkg ? cargoBuildType) true;
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;

    # The wrapper is what makes WebKit work outside a dev shell: GIO modules
    # (TLS), GStreamer plugins, GSettings schemas.
    wrappedForGApps = assay.eq (builtins.elem "wrap-gapps-hook" (names pkg.nativeBuildInputs)) true;
    # Without glib-networking every https:// page fails with a TLS error.
    hasGlibNetworking = assay.eq (builtins.elem "glib-networking" (names pkg.buildInputs)) true;
    # System libraries are linked from nixpkgs: the hook stays on.
    linksSystemLibs = assay.eq (pkg.dontCargoUseSystemLibs or false) false;

    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
