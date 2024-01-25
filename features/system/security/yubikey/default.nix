{
  settings,
  pkgs,
  ...
}: {
  services.udev.packages = with pkgs; [
    yubikey-personalization
  ];

  programs.gnupg.agent.enable = true;
  programs.gnupg.agent.enableSSHSupport = true;

  security.pam.services.login.u2fAuth = true;
  security.pam.services.sudo.u2fAuth = true;
}
