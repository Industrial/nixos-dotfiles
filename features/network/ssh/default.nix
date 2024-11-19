{...}: {
  services = {
    openssh = {
      enable = true;
    };
    sshguard = {
      enable = true;
    };
  };
}
