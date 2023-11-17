{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    #lutris-unwrapped

    # NTLM Support for wine (Path of Building)
    #samba

    # Beyond All Reason
    #openal
    #xdg-desktop-portal-gtk

    #xdg.portal.enable = true;
    #xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
    #services.flatpak.enable = true;
  ];
}
