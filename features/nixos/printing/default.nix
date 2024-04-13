{
  settings,
  pkgs,
  ...
}: {
  services.printing.enable = true;

  environment.systemPackages = with pkgs; [
    # # Unfree License
    # cnijfilter2
  ];
}
