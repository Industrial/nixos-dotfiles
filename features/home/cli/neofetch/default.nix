# neofetch is a command-line system information tool.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    neofetch
  ];
}
