{pkgs, ...}: {
  services.udev.packages = with pkgs; [
    yubikey-personalization
  ];

  # This rule locks the screen when the YubiKey is removed.
  services.udev.extraRules = ''
    ACTION=="remove",\
    ENV{SUBSYSTEM}=="usb",\
    ENV{PRODUCT}=="1050/402/556",\
    RUN+="${pkgs.util-linux}/bin/flock"
  '';

  programs.gnupg.agent.enable = true;
  programs.gnupg.agent.enableSSHSupport = true;

  security.pam.services.login.u2fAuth = true;
  security.pam.services.sudo.u2fAuth = true;
}
