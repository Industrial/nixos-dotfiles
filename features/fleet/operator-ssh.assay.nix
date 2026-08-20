let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./operator-ssh.nix;
in
  assay.suite "operator-ssh" {
    hasOperatorMap = assay.eq (builtins.match ".*operatorPubKeys = \\{.*" src != null) true;
    hasDrakkarKey = assay.eq (builtins.match ".*drakkar = \"ssh-ed25519.*" src != null) true;
    hasHuginnSlot = assay.eq (builtins.match ".*huginn = null.*" src != null) true;
    hasMimirSlot = assay.eq (builtins.match ".*mimir = null.*" src != null) true;
    hasIdentitiesOnly = assay.eq (builtins.match ".*IdentitiesOnly yes.*" src != null) true;
    hasFleetHosts = assay.eq (builtins.match ".*drakkar huginn mimir.*" src != null) true;
    hasNopasswdSudo = assay.eq (builtins.match ".*NOPASSWD.*" src != null) true;
  }
