# Colocated suite for features/nixos/etc-overlay/test-live-switch.nix, the feature's gate,
# once per fleet host. Evaluates each test's node (no VM is booted here;
# `nix build .#checks.x86_64-linux.etc-overlay-live-switch[-<host>]` runs it), so these
# claims pin what each gate starts from, what it switches into, and that what it follows is
# read off that host's own config.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inputs = nixos.flakeInputs;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (nixos) lib;
  fleet = import ../../../common/fleet.nix;

  gate = hostname: let
    test = import ./test-live-switch.nix {inherit pkgs inputs hostname;};
  in rec {
    inherit test;
    base = test.nodes.machine;
    withOverlay = base.gh185.withOverlay.config;
    inherit (base.gh185) facts;
  };
  drakkar = gate "drakkar";
  mimir = gate "mimir";
  huginn = gate "huginn";
  muninn = gate "muninn";
  all = [drakkar mimir huginn muninn];
in
  assay.suite "etc-overlay-live-switch-test" {
    # drakkar keeps the original name; every other host gets its own.
    named = assay.eq (map (g: g.test.name) all) [
      "vm-test-run-etc-overlay-live-switch"
      "vm-test-run-etc-overlay-live-switch-mimir"
      "vm-test-run-etc-overlay-live-switch-huginn"
      "vm-test-run-etc-overlay-live-switch-muninn"
    ];
    # One gate per fleet host, nothing missing.
    everyFleetHost = assay.eq (lib.sort lib.lessThan (map (g: g.base.networking.hostName) all)) (lib.sort lib.lessThan fleet.names);
    # Boots without the feature, and switches into the feature, not the bare option.
    bootsWithoutTheFeature = assay.eq (map (g: [g.base.features.nixos.etc-overlay.enable g.base.system.etc.overlay.enable]) all) (map (_: [false false]) all);
    entersTheFeature =
      assay.eq (map (g: [g.withOverlay.features.nixos.etc-overlay.enable g.withOverlay.system.etc.overlay.enable g.withOverlay.system.etc.overlay.mutable]) all) (map (_: [true true true]) all);
    # Leaving has to carry out, so the base generation holds the exit half.
    baseCarriesOut = assay.eq (map (g: g.base.system.activationScripts ? etcOverlayCarryOut) all) (map (_: true) all);
    # Switchable without specialisations, and the overlay generation's VM is in the image.
    switchable = assay.eq (map (g: [g.base.system.switch.enable g.withOverlay.system.switch.enable]) all) (map (_: [true true]) all);
    overlayVmInTheStore =
      assay.eq (map (g: map (d: d.name) g.base.system.extraDependencies) all) (map (g: [g.withOverlay.system.build.vm.name]) all);
    noSelfReference = assay.eq (map (g: g.withOverlay.system.extraDependencies) all) (map (_: []) all);
    # Two evaluations per host: no specialisations on top of the extension.
    noSpecialisations = assay.eq (map (g: [g.base.specialisation g.withOverlay.specialisation]) all) (map (_: [{} {}]) all);

    # What each gate follows, read off the host: the facts that differ between hosts.
    sshKeysFromHostKeys =
      assay.eq drakkar.facts.sshKeys ["ssh/ssh_host_rsa_key" "ssh/ssh_host_ed25519_key" "ssh/ssh_host_mldsa44_ed25519_key"];
    userDbPerHost = assay.eq (map (g: g.facts.userDb) all) ["userborn" "update-users-groups.pl" "update-users-groups.pl" "update-users-groups.pl"];
    networkManagerEverywhere = assay.eq (map (g: g.facts.networkmanager) all) [true true true true];
    # mimir (base-safe) and muninn (test-host, ADR-0008) carry the STIG identity watches, so
    # only their gates check the audit trail.
    auditWatchesOnMimirAndMuninn =
      assay.eq (map (g: g.facts.auditWatches != []) all) [false true false true];
    muninnWatchesPasswd = assay.eq (builtins.elem "/etc/passwd" muninn.facts.auditWatches) true;
    mimirWatchesPasswd = assay.eq (builtins.elem "/etc/passwd" mimir.facts.auditWatches) true;
    # vhealth only where the host runs it, as its own user (muninn since #437).
    vhealthPerHost = assay.eq (map (g: [g.facts.vhealth (g.base.users.users ? vhealth)]) all) [[true true] [true true] [false false] [true true]];
    # Units a VM cannot run: vcache (tailnet) on drakkar, comin (GitHub) on huginn. muninn is
    # deployed by vdeploy since #437.
    offlineUnits = assay.eq (map (g: g.facts.offline) all) [["vcache.service"] [] ["comin.service"] []];
  }
