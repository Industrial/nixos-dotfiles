# Colocated suite for rust/tools/nixos-update-notifier/default.nix — the buildRustPackage
# derivation features/cli/nixos-update-notifier installs.
#
# Built with callPackage from the pinned nixpkgs. Claims read the derivation's attributes;
# Cargo.toml is TOML and is parsed, so the Nix identity is checked against the crate's own.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  pkg = pkgs.callPackage ./default.nix {};
  crate = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package;
in
  assay.suite "nixos-update-notifier" {
    pnameIsTheCrateName = assay.eq pkg.pname crate.name;
    versionIsTheCrateVersion = assay.eq pkg.version crate.version;

    # buildRustPackage with the dependencies vendored from the checked-in Cargo.lock, so no
    # cargoHash has to be bumped alongside it.
    usesBuildRustPackage = assay.eq (pkg ? cargoDeps && pkg ? cargoBuildType) true;
    vendorsFromCargoLock = assay.eq (pkg.cargoHash or null) null;

    # The binary shells out to nix and git; the wrapper puts them on its PATH.
    wrapsTheBinaryWithItsTools = assay.eq (builtins.all (p: lib.hasInfix (builtins.unsafeDiscardStringContext "${lib.getBin p}/bin") pkg.postInstall)
      [pkgs.nix pkgs.git pkgs.coreutils pkgs.util-linux])
    true;
    wrapsTheInstalledBinary =
      assay.eq (lib.hasInfix "wrapProgram $out/bin/nixos-update-notifier" pkg.postInstall) true;

    mainProgram = assay.eq pkg.meta.mainProgram "nixos-update-notifier";
    # It reads /run/current-system and talks to the session D-Bus.
    linuxOnly =
      assay.eq [(builtins.all (lib.hasSuffix "-linux") pkg.meta.platforms) (builtins.elem "x86_64-linux" pkg.meta.platforms)] [true true];
  }
