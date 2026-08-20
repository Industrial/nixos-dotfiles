# ONLYOFFICE Desktop Editors — local office suite (docs, sheets, slides).
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    onlyoffice-desktopeditors
  ];
}
