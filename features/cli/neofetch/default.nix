# neofetch is a command-line system information tool.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    neofetch
  ];
}
