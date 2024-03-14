{
  settings,
  pkgs,
  ...
}: {
  # TODO: Lemmy doesn't work right now. We need to create an admin user.
  services.lemmy.enable = true;
  services.lemmy.settings.hostname = "localhost";
  services.lemmy.settings.port = 4001;
  services.lemmy.ui.port = 4002;
  services.lemmy.database.createLocally = true;
}
