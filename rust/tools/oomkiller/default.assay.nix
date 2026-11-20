# Colocated suite for rust/tools/oomkiller/default.nix — the crate2nix-built oomkiller
# package features/cli/oomkiller runs as a system service.
#
# Built with callPackage from the pinned nixpkgs, through the generated Cargo.nix
# (Cargo.assay.nix covers that file). Cargo.toml is TOML and is parsed, so the built crate is
# checked against the crate's own identity.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  pkg = pkgs.callPackage ./default.nix {};
  crate = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package;
in
  assay.suite "oomkiller" {
    # The workspace member this wraps is the oomkiller crate, at the crate's version.
    buildsTheOomkillerCrate = assay.eq pkg.crateName crate.name;
    versionIsTheCrateVersion = assay.eq pkg.version crate.version;
    # crate2nix's buildRustCrate naming, which is what hasPackage and the service's ExecStart
    # path in features/cli/oomkiller resolve against.
    isNamedAsABuiltRustCrate = assay.eq pkg.name "rust_${crate.name}-${crate.version}";

    # The override replaces the crate's meta with the fleet's own.
    describesTheThreshold =
      assay.eq pkg.meta.description "A daemon that monitors system memory and kills the highest memory-consuming process when memory usage exceeds 90%";
    isMitLicensed = assay.eq pkg.meta.license.spdxId "MIT";
  }
