{...}: {
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PubkeyAuthentication = true;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
        MaxAuthTries = 3;
        X11Forwarding = false;
      };
    };

    sshguard = {
      enable = true;
      whitelist = [
        "127.0.0.1"
        "::1"
      ];
    };
  };
}
