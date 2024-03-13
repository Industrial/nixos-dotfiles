{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    monero-gui
    monero-cli
    xmrig
    p2pool
  ];
}
