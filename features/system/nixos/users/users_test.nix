let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.users.users.${settings.username}.isNormalUser;
    expected = true;
  }
  {
    actual = feature.users.users.${settings.username}.home;
    expected = settings.userdir;
  }
  {
    actual = feature.users.users.${settings.username}.description;
    expected = settings.userfullname;
  }
  {
    actual = feature.users.users.${settings.username}.extraGroups;
    expected = ["audio" "networkmanager" "plugdev" "wheel"];
  }
]
