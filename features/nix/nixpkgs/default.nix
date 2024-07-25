{settings, ...}: {
  nixpkgs = {
    hostPlatform = settings.hostPlatform;
    config = {
      allowUnfree = true;
      allowBroken = false;
    };
  };
}
