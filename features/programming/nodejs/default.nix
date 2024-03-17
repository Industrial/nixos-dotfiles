{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    nodejs
    nodePackages.pnpm
  ];
}
