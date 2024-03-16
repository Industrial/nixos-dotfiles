{
  settings,
  pkgs,
  ...
}: {
  services.printing.enable = true;

  environment.systemPackages = with pkgs; [
    cnijfilter2
  ];
}
