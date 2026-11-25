# Colocated suite for hosts/drakkar/configuration.nix — evaluated selection, not source text.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  features = import ../../lib/features.nix {inherit (nixos) lib;};
  cfg = features.evalSelection {
    modules = [
      ./configuration.nix
      {disabledModules = [./disko.nix ./filesystems.nix ./hardware.nix];}
    ];
  };
  has = f: builtins.elem f (features.enabledFeatures cfg);
in
  assay.suite "configuration" {
    enablesFleetAccess = assay.eq (has "fleet.remote-access") true;
    enablesGaming = assay.eq cfg.profiles.gaming.enable true;
    enablesAi = assay.eq cfg.profiles.ai.enable true;
    servesBuilds = assay.eq (has "fleet.nix-remote-builder-server") true;
    servesTheBinaryCache = assay.eq (has "nix.vcache") true;
    verifiesTheStore = assay.eq (has "nix.vverify") true;
    vbuildIsTheBuildHook = assay.eq (has "fleet.vbuild") true;
    # userborn manages the user database (GH-187; docs/runbooks/userborn.md).
    managesUsersWithUserborn = assay.eq cfg.features.nixos.users.userborn.enable true;
    # bin/update/flake runs vbump here; without it, it falls back to `nix flake update`.
    bumpsLocksPerInput = assay.eq (has "cli.vbump") true;
    installsVfetch = assay.eq (has "cli.vfetch") true;
    fetchesThroughVfetch = assay.eq (has "nix.vfetch") true;
    placesDotfilesWithVfiles = assay.eq (has "nixos.vfiles") true;
    # vgen prunes generations and keeps the boot menu in step; vgc collects (GH-190).
    managesGenerationsWithVgen = assay.eq [(has "nixos.vgen") (has "nixos.vgc")] [true true];
    amdGraphics = assay.eq [(has "nixos.graphics.amd") (has "nixos.graphics.intel")] [true false];
    noStigBaseSafe = assay.eq (has "security.stig.profiles.base-safe") false;
    # vdaemon-proxy answers these read ops itself, each after a clean shadow (GH-183, GH-224);
    # the rest stay in conformance mode, forwarded and compared.
    answersReadsNatively =
      assay.eq [(has "nix.vdaemon-proxy") cfg.features.nix.vdaemon-proxy.conformance cfg.features.nix.vdaemon-proxy.native]
      [true true ["IsValidPath" "QueryPathInfo" "QueryValidPaths"]];
    vdaemonNativeRollsBack = let
      off = features.evalSelection {
        modules = [
          ./configuration.nix
          {disabledModules = [./disko.nix ./filesystems.nix ./hardware.nix];}
          {features.nix.vdaemon-proxy.native = nixos.lib.mkForce [];}
        ];
      };
    in
      assay.eq [(builtins.elem "nix.vdaemon-proxy" (features.enabledFeatures off)) off.features.nix.vdaemon-proxy.native] [true []];
    # vdeploy deploys drakkar (its `vdeploy` role, GH-160) and comin is gone (GH-225).
    deploysWithVdeployNotComin = assay.eq [(has "nix.vdeploy") (has "fleet.comin")] [true false];
    vdeployRollsBack = let
      off = features.evalSelection {
        modules = [
          ./configuration.nix
          {disabledModules = [./disko.nix ./filesystems.nix ./hardware.nix];}
          {features.nix.vdeploy.enable = nixos.lib.mkForce false;}
        ];
      };
      on = f: builtins.elem f (features.enabledFeatures off);
    in
      assay.eq [(on "nix.vdeploy") (on "fleet.comin")] [false false];
    # /etc on the overlay, mutable, state carried across (GH-185).
    etcOnTheOverlay = assay.eq (has "nixos.etc-overlay") true;
    # Rollback: lib.mkForce false turns it off; that generation carries the state back out
    # (features/nixos/etc-overlay/default.assay.nix rollbackCarriesOut, and the VM gate).
    etcOverlayRollsBack = let
      off = features.evalSelection {
        modules = [
          ./configuration.nix
          {disabledModules = [./disko.nix ./filesystems.nix ./hardware.nix];}
          {features.nixos.etc-overlay.enable = nixos.lib.mkForce false;}
        ];
      };
    in
      assay.eq (builtins.elem "nixos.etc-overlay" (features.enabledFeatures off)) false;
  }
