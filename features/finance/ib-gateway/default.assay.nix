# Assay: Interactive Brokers Gateway, latest standalone Linux installer.
#
# The derivation is read out of the evaluated config's systemPackages and projected to the
# attributes that matter (pname, src, meta, build inputs) -- never compared whole. The install
# phase is a generated build script, so matching it as text is matching the artifact.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "ib-gateway-latest-standalone") null cfg.environment.systemPackages;
  aarch64 = nixos.eval {modules = [./default.nix {nixpkgs.hostPlatform = "aarch64-linux";}];};
  installHas = needle: lib.hasInfix needle pkg.installPhase;
in
  assay.suite "ib-gateway" {
    installsGateway = assay.eq (nixos.hasPackage cfg "ib-gateway-latest-standalone") true;
    notInstalledOffX86 = assay.eq (nixos.hasPackage aarch64 "ib-gateway-latest-standalone") false;

    sourceIsLatestStandaloneInstaller =
      assay.eq pkg.src.url
      "https://download2.interactivebrokers.com/installers/ibgateway/latest-standalone/ibgateway-latest-standalone-linux-x64.sh";
    pinsInstallerHash = assay.eq pkg.src.outputHash "sha256-exuclHkgWwMccocdLXLiPFgRnAWGw08cVCERwvsk13w=";

    # The bundled JRE needs an FHS environment, at install time and at launch.
    installerRunsUnderSteamRun = assay.eq (map lib.getName pkg.nativeBuildInputs) ["steam-run"];
    # steam-run lacks libXtst & co; without them the bundled AWT fails to load.
    launcherInjectsAwtXLibs = assay.eq (installHas "ib-gateway-awt-xlibs/lib") true;
    installsDesktopEntry = assay.eq (installHas "share/applications/ib-gateway.desktop") true;

    mainProgramIsIbgateway = assay.eq pkg.meta.mainProgram "ibgateway";
    licenseIsUnfree = assay.eq pkg.meta.license.shortName "unfree";
    platformsX86Only = assay.eq pkg.meta.platforms ["x86_64-linux"];
  }
