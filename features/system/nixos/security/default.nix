{
  settings,
  pkgs,
  ...
}: {
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = true;
  security.sudo.execWheelOnly = true;
}
