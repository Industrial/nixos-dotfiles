{...}: {
  services = {
    openssh = {
      enable = true;

      settings = {
        # Enable password authentication.
        PasswordAuthentication = true;

        # Disable challenge response authentication.
        KbdInteractiveAuthentication = false;
      };

      # Disable SFTP.
      allowSFTP = false;

      # Disable TCP port forwarding, X11 forwarding, agent forwarding, stream
      # local forwarding and only allow public key authentication.
      extraConfig = ''
        AllowTcpForwarding yes
        X11Forwarding no
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
      '';
      # AuthenticationMethods publickey
    };

    # Set up sshguard, which will block SSH connections from unknown hosts.
    sshguard = {
      enable = true;
    };
  };
}
