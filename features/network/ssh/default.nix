{...}: {
  services = {
    openssh = {
      enable = true;

      settings = {
        # Disable password authentication for security
        PasswordAuthentication = false;

        # Enable public key authentication
        PubkeyAuthentication = true;

        # Disable root login
        PermitRootLogin = "no";

        # Limit authentication attempts
        MaxAuthTries = 3;

        # Set client alive settings
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;

        # Disable challenge response authentication
        KbdInteractiveAuthentication = false;

        # Disable GSSAPI authentication
        GSSAPIAuthentication = false;

        # Disable host-based authentication
        HostbasedAuthentication = false;

        # Disable rhosts authentication
        IgnoreRhosts = true;

        # Disable empty passwords
        PermitEmptyPasswords = false;

        # Set login grace time
        LoginGraceTime = "30";

        # Disable X11 forwarding
        X11Forwarding = false;

        # Disable agent forwarding
        AllowAgentForwarding = false;

        # Disable TCP forwarding
        AllowTcpForwarding = false;

        # Disable stream local forwarding
        AllowStreamLocalForwarding = false;

        # Disable gateway ports
        GatewayPorts = "no";

        # Disable user environment
        PermitUserEnvironment = false;

        # Set strict modes
        StrictModes = true;

        # Set maximum sessions
        MaxSessions = 10;

        # Set maximum startups
        MaxStartups = "10:30:60";

        # Disable compression
        Compression = false;

        # Set protocol version
        Protocol = 2;

        # Set host key algorithms
        HostKeyAlgorithms = "ssh-ed25519,ssh-rsa";

        # Set key exchange algorithms
        KexAlgorithms = "curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256";

        # Set cipher algorithms
        Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr";

        # Set MAC algorithms
        MACs = "hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com";
      };

      # Disable SFTP for security
      allowSFTP = false;
    };

    # Set up sshguard, which will block SSH connections from unknown hosts
    sshguard = {
      enable = true;
      # Configure sshguard with stricter settings
      whitelist = [
        "127.0.0.1"
        "::1"
      ];
      blacklist = [];
      # Set attack threshold
      attack_threshold = 3;
      # Set block time
      block_time = 600;
      # Set detection time
      detection_time = 60;
    };
  };
}
