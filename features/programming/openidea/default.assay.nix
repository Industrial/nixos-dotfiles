# Assay: OpenIDEA from its upstream AppImage, plus the Node its Agents panel needs.
#
# Claims read the evaluated config: the packages in systemPackages and the pinned release.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "openidea") null cfg.environment.systemPackages;
  aarch64 = nixos.eval {modules = [./default.nix {nixpkgs.hostPlatform = "aarch64-linux";}];};
in
  assay.suite "openidea" {
    installsOpenidea = assay.eq (nixos.hasPackage cfg "openidea") true;
    pinsVersion = assay.eq pkg.version "0.1.18";
    sourceIsTheVersionedAppImage =
      assay.eq pkg.src.url
      "https://github.com/l0ng-ai/openidea/releases/download/v0.1.18/OpenIDEA_0.1.18_amd64.AppImage";
    pinsAppImageHash = assay.eq pkg.src.outputHash "sha256-M1XD759ZQdNQIqYhhn1J81TO6Z1ZD+DCL1gjidsy8Bs=";
    wrappedInFhsEnv = assay.eq (pkg ? fhsenv) true;
    mainProgramIsOpenidea = assay.eq pkg.meta.mainProgram "openidea";
    # The desktop entry is rewritten to launch the wrapper, not the AppImage's own binary.
    desktopEntryExecsWrapper = assay.eq (lib.hasInfix "Exec=openidea" pkg.buildCommand) true;

    # `npx` must reach the login shell for the Agents panel's ACP adapters. Full nodejs, not
    # nodejs-slim: the slim build ships no npm/npx.
    provisionsNodejs = assay.eq (nixos.hasPackage cfg "nodejs") true;
    notNodejsSlim = assay.eq (nixos.hasPackage cfg "nodejs-slim") false;

    # Upstream ships amd64 only, and the Node pin goes with it.
    nothingInstalledOffX86 =
      assay.eq (map (nixos.hasPackage aarch64) ["openidea" "nodejs"]) [false false];
  }
