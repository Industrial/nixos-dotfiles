{settings, ...}: {
  nix = {
    settings = {
      trusted-users = ["root" "${settings.username}"];
    };
  };
}
