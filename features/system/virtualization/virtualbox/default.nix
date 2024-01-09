{
  settings,
  pkgs,
  ...
}: {
  users.extraGroups.vboxusers.members = [settings.username];
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  virtualisation.virtualbox.guest.enable = true;
  virtualisation.virtualbox.guest.x11 = true;
}
