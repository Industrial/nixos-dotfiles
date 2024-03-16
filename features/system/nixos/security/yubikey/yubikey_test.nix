let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem pkgs.yubikey-personalization feature.services.udev.packages;
    expected = true;
  }
  {
    actual = feature.services.udev.extraRules;
    expected = ''
      ACTION=="remove",\
      ENV{SUBSYSTEM}=="usb",\
      ENV{PRODUCT}=="1050/402/556",\
      RUN+="${pkgs.util-linux}/bin/flock"
    '';
  }
  {
    actual = feature.programs.gnupg.agent.enable;
    expected = true;
  }
  {
    actual = feature.programs.gnupg.agent.enableSSHSupport;
    expected = true;
  }
  {
    actual = feature.security.pam.services.login.u2fAuth;
    expected = true;
  }
  {
    actual = feature.security.pam.services.sudo.u2fAuth;
    expected = true;
  }
]
