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
      enableSSHAgentAuth = true;
      enableOTPW = false;
      enablePAM = true;
    };
  };
}
