let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "users_test/nix.settings.trusted-users";
    actual = feature.nix.settings.trusted-users;
    expected = ["root" "${settings.username}"];
  }
  {
    name = "users_test";
    actual = feature.users.users.${settings.username}.isNormalUser;
    expected = true;
  }
  {
    name = "users_test";
    actual = feature.users.users.${settings.username}.home;
    expected = settings.userdir;
  }
  {
    name = "users_test";
    actual = feature.users.users.${settings.username}.description;
    expected = settings.userfullname;
  }
  {
    name = "users_test";
    actual = feature.users.users.${settings.username}.extraGroups;
    expected = ["audio" "networkmanager" "plugdev" "wheel"];
  }
]
