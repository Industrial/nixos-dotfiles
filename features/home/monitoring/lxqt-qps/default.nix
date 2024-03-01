# QPS is a simple process manager for LXQT.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    lxqt.qps
  ];
}
