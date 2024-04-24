{
  settings,
  pkgs,
  ...
}: {
  nixpkgs = {
    hostPlatform = settings.hostPlatform;
    config = {
      allowUnfree = true;
      allowBroken = false;
    };
  };
}
