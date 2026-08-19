{...}: {
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PubkeyAuthentication = true;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
        # Low by design; fleet clients use IdentitiesOnly (see features/fleet/operator-ssh.nix).
        MaxAuthTries = 3;
        X11Forwarding = false;
      };
    };

    sshguard = {
      enable = true;
      whitelist = [
        "127.0.0.1"
        "::1"
        # Tailscale CGNAT — fleet peers authenticate over the mesh.
        "100.64.0.0/10"
      ];
    };
  };
}
