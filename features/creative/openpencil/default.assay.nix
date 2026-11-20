# Assay: OpenPencil, wrapped from the upstream AppImage.
#
# Claims read the evaluated NixOS config: the package that lands in systemPackages, and the
# pinned release it was built from. A version bump that forgets the URL (or the reverse) shows
# up as a mismatch between `version` and `src.url` rather than as a silent wrong download.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "openpencil") null cfg.environment.systemPackages;
  # The same module on a non-x86 host: upstream ships only an amd64 AppImage.
  aarch64 = nixos.eval {modules = [./default.nix {nixpkgs.hostPlatform = "aarch64-linux";}];};
in
  assay.suite "openpencil" {
    installsOpenpencil = assay.eq (nixos.hasPackage cfg "openpencil") true;
    pinsVersion = assay.eq pkg.version "0.10.0";
    sourceIsTheVersionedAppImage =
      assay.eq pkg.src.url
      "https://github.com/open-pencil/open-pencil/releases/download/v0.10.0/OpenPencil_0.10.0_amd64.AppImage";
    pinsAppImageHash = assay.eq pkg.src.outputHash "sha256-9SdHH1c4z9fQ2EBc7jgr5mY4iR8FZOb3h3FKP6xTW6I=";
    # wrapType2 runs the AppImage inside an FHS env; a bare fetch would hit stub-ld.
    wrappedInFhsEnv = assay.eq (pkg ? fhsenv) true;
    notInstalledOffX86 = assay.eq (nixos.hasPackage aarch64 "openpencil") false;
  }
