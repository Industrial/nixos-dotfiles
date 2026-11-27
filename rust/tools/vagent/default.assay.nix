# Colocated suite for rust/tools/vagent/default.nix: the buildRustPackage derivation of the
# agent-session launcher (ADR-0009, #353).
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  pkg = pkgs.callPackage ./default.nix {};
  manifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
  crate = manifest.package;
in
  assay.suite "vagent" {
    pnameIsTheCrateName = assay.eq pkg.pname crate.name;
    versionIsTheCrateVersion = assay.eq pkg.version crate.version;
    usesBuildRustPackage = assay.eq (pkg ? cargoDeps && pkg ? cargoBuildType) true;
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;
    standaloneWorkspace = assay.eq (manifest.workspace or null) {};
    idEffectPinned = assay.eq [manifest.dependencies.id_effect manifest.dependencies.id_effect_cli] ["=0.13.0" "=0.13.0"];
    voltaicPinned = assay.eq [manifest.build-dependencies.voltaic-driver manifest.build-dependencies.voltaic-diag] ["=0.3.0" "=0.3.0"];
    sourceIsVoltaic =
      assay.eq (map (f: builtins.pathExists "${pkg.src}/src/${f}.vlt") ["app" "cli" "common" "plan" "world"]) [true true true true true];
    mainProgram = assay.eq pkg.meta.mainProgram "vagent";
    linuxOnly = assay.eq (builtins.elem "x86_64-linux" pkg.meta.platforms) true;
  }
