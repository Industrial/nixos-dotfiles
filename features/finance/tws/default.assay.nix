# Assay: Interactive Brokers Trader Workstation, stable standalone Linux installer.
#
# The derivation is read out of the evaluated config's systemPackages and projected to the
# attributes that matter (pname, src, meta, build inputs) -- never compared whole. The install
# phase is a generated build script, so matching it as text is matching the artifact.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  pkg = lib.findFirst (p: lib.getName p == "ib-tws-stable-standalone") null cfg.environment.systemPackages;
  aarch64 = nixos.eval {modules = [./default.nix {nixpkgs.hostPlatform = "aarch64-linux";}];};
  installHas = needle: lib.hasInfix needle pkg.installPhase;
in
  assay.suite "tws" {
    installsTws = assay.eq (nixos.hasPackage cfg "ib-tws-stable-standalone") true;
    notInstalledOffX86 = assay.eq (nixos.hasPackage aarch64 "ib-tws-stable-standalone") false;

    sourceIsStableStandaloneInstaller =
      assay.eq pkg.src.url
      "https://download2.interactivebrokers.com/installers/tws/stable-standalone/tws-stable-standalone-linux-x64.sh";
    pinsInstallerHash = assay.eq pkg.src.outputHash "sha256-GkTIMbhr4bEeX2oImsxkBXc2ZT9pdhL88pEfNPIm2vE=";

    # steam-run binds /etc/zoneinfo, absent in the build sandbox, so the installer runs in a
    # purpose-built FHS env instead; the launcher still uses steam-run at runtime.
    installerRunsInBuildFhs = assay.eq (map lib.getName pkg.nativeBuildInputs) ["ib-tws-installer-fhs"];
    launcherUsesSteamRun = assay.eq (installHas "/bin/steam-run") true;
    # A real .desktop entry pointing at our wrapper, so GNOME never runs upstream's `tws`.
    installsDesktopEntry = assay.eq (installHas "share/applications/ib-tws.desktop") true;

    mainProgramIsTws = assay.eq pkg.meta.mainProgram "tws";
    licenseIsUnfree = assay.eq pkg.meta.license.shortName "unfree";
    platformsX86Only = assay.eq pkg.meta.platforms ["x86_64-linux"];
  }
