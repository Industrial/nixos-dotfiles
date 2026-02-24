{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    xfce.xfce4-screenshooter
  ];
}
