{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    monero-gui
    monero-cli
    xmrig
    p2pool
  ];
}
