# Colocated suite for hosts/mimir/configuration.nix — which profiles and features mimir
# switches on, evaluated through the option layer. Hardware/disk files set real NixOS
# options and are covered by their own suites, so they are disabled here.
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
    enablesBase = assay.eq cfg.profiles.base.enable true;
    enablesFleetAccess = assay.eq (has "fleet.remote-access") true;
    enablesNfsServer = assay.eq (has "storage.nfs-server") true;

    # mimir is the always-on host, so it carries the RustDesk signal/relay for the fleet.
    enablesRemoteDesktopRelay = assay.eq (has "fleet.remote-desktop-relay") true;

    # The STIG base-safe baseline lives here and nowhere else (ADR-0004).
    enablesStigBaseSafe = assay.eq (has "security.stig.profiles.base-safe") true;

    # mimir offloads builds rather than serving them.
    buildClientNotServer = assay.eq [(has "fleet.nix-remote-builder-client") (has "fleet.nix-remote-builder-server")] [true false];

    noGaming = assay.eq cfg.profiles.gaming.enable false;

    # The desktop profile brings GNOME and Hyprland; mimir keeps GNOME only.
    gnomeWithoutHyprland = assay.eq [(has "window-manager.gnome") (has "window-manager.hyprland")] [true false];

    # vdeploy deploys mimir (GH-160): the vdeploy role in common/fleet.nix, with vhealth
    # for its health checks. comin is gone (GH-225; hosts/fleet.assay.nix checks the
    # evaluated services).
    deploysWithVdeploy = assay.eq [(has "nix.vdeploy") (has "nix.vhealth") (has "fleet.comin")] [true true false];
    aDeployHost = assay.eq ((import ../../common/fleet.nix).hasRole "vdeploy" "mimir") true;
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
