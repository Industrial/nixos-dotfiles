args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_services_udev_packages = {
    expr = builtins.elem pkgs.yubikey-personalization feature.services.udev.packages;
    expected = true;
  };
  test_services_udev_extraRules = {
    expr = feature.services.udev.extraRules;
    expected = ''
      ACTION=="remove",\
      ENV{SUBSYSTEM}=="usb",\
      ENV{PRODUCT}=="1050/402/556",\
      RUN+="${pkgs.util-linux}/bin/flock"
    '';
  };
  test_programs_gnupg_agent_enable = {
    expr = feature.programs.gnupg.agent.enable;
    expected = true;
  };
  test_programs_gnupg_agent_enableSSHSupport = {
    expr = feature.programs.gnupg.agent.enableSSHSupport;
    expected = true;
  };
  test_security_pam_services_login_u2fAuth = {
    expr = feature.security.pam.services.login.u2fAuth;
    expected = true;
  };
  test_security_pam_services_sudo_u2fAuth = {
    expr = feature.security.pam.services.sudo.u2fAuth;
    expected = true;
  };
}
