# Assay: Awakened PoE Trade, wrapped from the upstream AppImage.
#
# Claims read the evaluated NixOS config: the package in systemPackages and the pinned release
# it comes from, so a bump that moves `version` without the URL (or the reverse) fails here.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "awakened-poe-trade") null cfg.environment.systemPackages;
  aarch64 = nixos.eval {modules = [./default.nix {nixpkgs.hostPlatform = "aarch64-linux";}];};
in
  assay.suite "awakened-poe-trade" {
    installsAwakenedPoeTrade = assay.eq (nixos.hasPackage cfg "awakened-poe-trade") true;
    pinsVersion = assay.eq pkg.version "3.29.104";
    sourceIsTheVersionedAppImage =
      assay.eq pkg.src.url
      "https://github.com/SnosMe/awakened-poe-trade/releases/download/v3.29.104/Awakened-PoE-Trade-3.29.104.AppImage";
    pinsAppImageHash = assay.eq pkg.src.outputHash "sha256-ApZwjy1tJwUtevLA7QY8/zrnHI5Tt4aXMpTo+5VWGUg=";
    # appimageTools.wrapType2: the Electron AppImage runs inside an FHS env.
    wrapsAppImage = assay.eq (pkg ? fhsenv) true;
    metaPlatformsX86Only = assay.eq pkg.meta.platforms ["x86_64-linux"];
    notInstalledOffX86 = assay.eq (nixos.hasPackage aarch64 "awakened-poe-trade") false;
  }
