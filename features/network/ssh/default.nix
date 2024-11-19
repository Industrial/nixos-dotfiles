{...}: {
  services = {
    sshd = {
      enable = true;
    };
    sshguard = {
      enable = true;
    };
  };
}
