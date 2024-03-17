{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    homebank
  ];
}
