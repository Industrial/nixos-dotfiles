args @ {settings, ...}: let
  feature = import ./default.nix args;
in {
  test_system_stateVersion = {
    expr = feature.system.stateVersion;
    expected = settings.stateVersion;
  };
  test_networking_hostName = {
    expr = feature.networking.hostName;
    expected = settings.hostname;
  };
  test_networking_useDHCP = {
    expr = feature.networking.useDHCP;
    expected = false;
  };
  test_networking_interfaces_eth0_useDHCP = {
    expr = feature.networking.interfaces.eth0.useDHCP;
    expected = true;
  };
  # test_users_users_test_extraGroups = {
  #   expr = feature.users.users.test.extraGroups;
  #   expected = ["wheel"];
  # };
  # test_users_users_test_isNormalUser = {
  #   expr = feature.users.users.test.isNormalUser;
  #   expected = true;
  # };
  test_security_sudo_wheelNeedsPassword = {
    expr = feature.security.sudo.wheelNeedsPassword;
    expected = false;
  };
  test_services_getty_autologinUser = {
    expr = feature.services.getty.autologinUser;
    expected = settings.username;
  };
}
