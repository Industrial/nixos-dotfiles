let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "yubikey_test";
    actual = builtins.elem pkgs.yubikey-personalization feature.services.udev.packages;
    expected = true;
  }
  {
    name = "yubikey_test";
    actual = feature.services.udev.extraRules;
    expected = ''
      ACTION=="remove",\
      ENV{SUBSYSTEM}=="usb",\
      ENV{PRODUCT}=="1050/402/556",\
      RUN+="${pkgs.util-linux}/bin/flock"
    '';
  }
  {
    name = "yubikey_test";
    actual = feature.programs.gnupg.agent.enable;
    expected = true;
  }
  {
    name = "yubikey_test";
    actual = feature.programs.gnupg.agent.enableSSHSupport;
    expected = true;
  }
  {
    name = "yubikey_test";
    actual = feature.security.pam.services.login.u2fAuth;
    expected = true;
  }
  {
    name = "yubikey_test";
    actual = feature.security.pam.services.sudo.u2fAuth;
    expected = true;
  }
]
