{lib, ...}: {
  # Enforces no default environment packages by setting defaultPackages to an
  # empty list, using mkForce to override other configurations.
  environment = {
    defaultPackages = lib.mkForce [];
  };
}
