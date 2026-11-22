# Assay: fleet remote builder client — offloads builds to the online fleet builders.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  fleet = import ../../common/fleet.nix;
  cfg = nixos.eval {modules = [./nix-remote-builder-client.nix];};
  machines = cfg.nix.buildMachines;
  hostNames = map (m: m.hostName) machines;
  sshConfig = cfg.programs.ssh.extraConfig;
  offline = builtins.filter (n: !(fleet.isOnline n)) fleet.order;
in
  assay.suite "nix-remote-builder-client" {
    enablesDistributed = assay.eq cfg.nix.distributedBuilds true;
    # huginn and muninn are offline (common/fleet.nix `online = false`, GH-252).
    targetsFleetBuilders = assay.eq hostNames ["drakkar"];
    targetsOnlyTheFleetsBuilders = assay.eq hostNames (map (b: b.name) fleet.builders);

    # A dead builder costs a TCP timeout per derivation (GH-252): none is listed.
    noOfflineBuilder = assay.eq [(offline != []) (builtins.filter (n: builtins.elem n offline) hostNames)] [true []];

    # drakkar is the big box: it alone takes big-parallel jobs and is preferred.
    onlyDrakkarBigParallel =
      assay.eq
      (map (m: m.hostName) (builtins.filter (m: builtins.elem "big-parallel" m.supportedFeatures) machines))
      ["drakkar"];

    # Builders log in as the operator with the operator's key.
    sshAsOperator = assay.eq (builtins.all (m: m.sshUser == nixos.defaultSettings.username) machines) true;
    usesSubstitutes = assay.eq cfg.nix.settings.builders-use-substitutes true;

    # Every builder gets a 5 s ssh ConnectTimeout in the system ssh_config, so one dead
    # builder cannot stall a build for minutes (GH-252).
    connectTimeoutForEveryBuilder =
      assay.eq
      (builtins.match ".*Host ${builtins.concatStringsSep " " hostNames}\n +ConnectTimeout 5\n.*" sshConfig != null)
      true;
  }
