# Assay: fleet operator SSH — one key per host, passwordless sudo, client defaults.
#
# programs.ssh.extraConfig is matched as text because it IS text: the generated
# ssh_config fragment is the artifact, not the module source.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./operator-ssh.nix];};
  user = nixos.defaultSettings.username;
  keys = cfg.users.users.${user}.openssh.authorizedKeys.keys;
  fleet = ["drakkar" "huginn" "mimir" "muninn"];
  keyFor = host: builtins.any (k: builtins.match "ssh-ed25519 [^ ]+ [^@]+@${host}" k != null) keys;
  sshConfig = cfg.programs.ssh.extraConfig;
in
  assay.suite "operator-ssh" {
    # Every fleet host's operator key is enrolled, and nothing else.
    enrollsEveryFleetHost = assay.eq (builtins.all keyFor fleet) true;
    onlyFleetKeys = assay.eq (builtins.length keys) (builtins.length fleet);

    nopasswdSudoForOperator =
      assay.eq
      (builtins.any (r:
        builtins.elem user (r.users or [])
        && builtins.any (c: c.command == "ALL" && builtins.elem "NOPASSWD" c.options) r.commands)
      cfg.security.sudo.extraRules)
      true;

    sshConfigCoversFleet = assay.eq (builtins.match ".*Host drakkar huginn mimir muninn\n.*" sshConfig != null) true;
    sshConfigIdentitiesOnly = assay.eq (builtins.match ".*IdentitiesOnly yes.*" sshConfig != null) true;
  }
