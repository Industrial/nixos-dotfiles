args @ {settings, ...}: let
  feature = import ./default.nix args;
in {
  test_nix_settings_trustedUsers = {
    expr = feature.nix.settings.trusted-users;
    expected = ["root" "${settings.username}"];
  };
  test_users_users_username_isNormalUser = {
    expr = feature.users.users.${settings.username}.isNormalUser;
    expected = true;
  };
  test_users_users_username_home = {
    expr = feature.users.users.${settings.username}.home;
    expected = settings.userdir;
  };
  test_users_users_username_description = {
    expr = feature.users.users.${settings.username}.description;
    expected = settings.userfullname;
  };
  test_users_users_username_extraGroups = {
    expr = feature.users.users.${settings.username}.extraGroups;
    expected = ["audio" "networkmanager" "plugdev" "wheel" "data"];
  };
}
