{
  config,
  lib,
  pkgs,
  ...
}: {
  # PAM security configuration

  security = {
    # Configure PAM for better authentication
    pam = {
      sshAgentAuth = {
        enable = true;
      };
      enableOTPW = false;
    };
  };
}
