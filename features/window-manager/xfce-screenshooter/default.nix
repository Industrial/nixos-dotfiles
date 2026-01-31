{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    xfce4-screenshooter
  ];
}
