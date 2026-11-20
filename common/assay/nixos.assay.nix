# Assay: the NixOS eval helper the other suites stand on.
#
# If the helper quietly evaluated something other than the real option tree, every suite
# built on it would pass for the wrong reason, so its own behaviour is pinned here.
let
  assay = import ./default.nix;
  nixos = import ./nixos.nix;

  withPort = nixos.eval {
    modules = [
      ({lib, ...}:
        lib.mkMerge [
          {networking.firewall.allowedTCPPorts = [1234];}
          {networking.firewall.interfaces.eth0.allowedUDPPorts = [5678];}
        ])
    ];
  };
  withPkg = nixos.eval {modules = [({pkgs, ...}: {environment.systemPackages = [pkgs.hello];})];};
  withSettings = nixos.eval {
    modules = [({settings, ...}: {networking.hostName = settings.hostname;})];
    settings.hostname = "probe";
  };
in
  assay.suite "assay-nixos" {
    # The empty system publishes nothing, so "no ports beyond baseline" is a real bar.
    baselineOpensNoTCP = assay.eq (nixos.openTCPPorts nixos.baseline) [];
    baselineOpensNoUDP = assay.eq (nixos.openUDPPorts nixos.baseline) [];

    # Ports are seen through mkMerge and per-interface rules — what source regexes missed.
    seesMergedTCPPort = assay.eq (nixos.openTCPPorts withPort) [1234];
    seesInterfaceUDPPort = assay.eq (nixos.openUDPPorts withPort) [5678];

    seesPackage = assay.eq (nixos.hasPackage withPkg "hello") true;
    baselineLacksPackage = assay.eq (nixos.hasPackage nixos.baseline "hello") false;

    settingsOverrideReachModules = assay.eq withSettings.networking.hostName "probe";
    settingsKeepDefaults = assay.eq nixos.defaultSettings.username "tom";

    # Real option tree: setting an option that does not exist is an eval error, not a pass.
    # (assay.throws takes an expression string: the runner re-evaluates it in isolation.)
    rejectsUnknownOption =
      assay.throws
      "((import ${toString ./nixos.nix}).eval {modules = [{services.no-such-service.enable = true;}];}).networking.hostName"
      "services.no-such-service' does not exist";

    # Control for the claim above: the same read on a valid system succeeds, so the throw
    # comes from the unknown option and not from the read itself.
    shallowReadSucceeds = assay.eq nixos.baseline.networking.hostName "nixos";
  }
