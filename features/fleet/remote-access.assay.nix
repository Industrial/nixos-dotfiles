# Assay: fleet remote access.
#
# comin itself moved to features/fleet/comin.nix and is enabled there per host
# (ADR-0002). The noComin claim below is still load-bearing: activation
# semantics must not be smuggled into an access module.
#
# Claims read the evaluated config of the whole import tree, so "imports X" is
# asserted by what X contributes, and a negative claim cannot be failed by the
# comment explaining it.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./remote-access.nix];};
in
  assay.suite "remote-access" {
    # features/security/tailscale ships it disabled; this module must force it on.
    enablesTailscale = assay.eq cfg.services.tailscale.enable true;
    trustsTailnet = assay.eq (builtins.elem "tailscale0" cfg.networking.firewall.trustedInterfaces) true;

    # features/network/ssh: key-only sshd.
    enablesSshd = assay.eq cfg.services.openssh.enable true;
    sshdKeyOnly = assay.eq cfg.services.openssh.settings.PasswordAuthentication false;

    # operator-ssh.nix: the operator account gets the fleet keys.
    importsOperatorSsh =
      assay.eq
      (cfg.users.users.${nixos.defaultSettings.username}.openssh.authorizedKeys.keys != [])
      true;

    # Fleet-wide RustDesk client rides in through this module, since every host
    # imports it. The relay half must stay out (mimir imports that directly).
    importsRemoteDesktop = assay.eq (nixos.hasPackage cfg "rustdesk") true;
    noRelayHere = assay.eq cfg.services.rustdesk-server.enable false;

    # services.comin only exists once its module is imported; either way it must not be on.
    noComin = assay.eq ((cfg.services.comin.enable or false) == true) false;
  }
