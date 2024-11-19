{...}: {
  services = {
    openssh = {
      enable = true;

      # Disable password authentication.
      passwordAuthentication = false;

      # Disable SFTP.
      allowSFTP = false;

      # Disable challenge response authentication.
      challengeResponseAuthentication = false;

      # Disable TCP port forwarding, X11 forwarding, agent forwarding, stream
      # local forwarding and only allow public key authentication.
      extraConfig = ''
        AllowTcpForwarding yes
        X11Forwarding no
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
        AuthenticationMethods publickey
      '';
    };

    # Set up sshguard, which will block SSH connections from unknown hosts.
    sshguard = {
      enable = true;
    };
  };
}
