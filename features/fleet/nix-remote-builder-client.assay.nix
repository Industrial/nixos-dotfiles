# Assay: fleet remote builder client — offloads builds to drakkar, muninn and huginn.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./nix-remote-builder-client.nix];};
  machines = cfg.nix.buildMachines;
in
  assay.suite "nix-remote-builder-client" {
    enablesDistributed = assay.eq cfg.nix.distributedBuilds true;
    targetsFleetBuilders = assay.eq (map (m: m.hostName) machines) ["drakkar" "muninn" "huginn"];

    # drakkar is the big box: it alone takes big-parallel jobs and is preferred.
    onlyDrakkarBigParallel =
      assay.eq
      (map (m: m.hostName) (builtins.filter (m: builtins.elem "big-parallel" m.supportedFeatures) machines))
      ["drakkar"];

    # Builders log in as the operator with the operator's key.
    sshAsOperator = assay.eq (builtins.all (m: m.sshUser == nixos.defaultSettings.username) machines) true;
    usesSubstitutes = assay.eq cfg.nix.settings.builders-use-substitutes true;
  }
