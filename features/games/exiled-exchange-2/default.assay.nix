# Assay: Exiled Exchange 2, wrapped from the upstream AppImage.
#
# Claims read the evaluated NixOS config: the package in systemPackages and the pinned release
# it comes from, so a bump that moves `version` without the URL (or the reverse) fails here.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "exiled-exchange-2") null cfg.environment.systemPackages;
  aarch64 = nixos.eval {modules = [./default.nix {nixpkgs.hostPlatform = "aarch64-linux";}];};
in
  assay.suite "exiled-exchange-2" {
    installsExiledExchange2 = assay.eq (nixos.hasPackage cfg "exiled-exchange-2") true;
    pinsVersion = assay.eq pkg.version "0.12.2";
    sourceIsTheVersionedAppImage =
      assay.eq pkg.src.url
      "https://github.com/Kvan7/Exiled-Exchange-2/releases/download/v0.12.2/exiled-exchange-2-0.12.2.AppImage";
    pinsAppImageHash = assay.eq pkg.src.outputHash "sha256-8SK/Fqf3t9G9hPNLnaNxgBNgMVv4Rke96xi9ufvbEHs=";
    wrapsAppImage = assay.eq (pkg ? fhsenv) true;
    metaPlatformsX86Only = assay.eq pkg.meta.platforms ["x86_64-linux"];
    notInstalledOffX86 = assay.eq (nixos.hasPackage aarch64 "exiled-exchange-2") false;
  }
