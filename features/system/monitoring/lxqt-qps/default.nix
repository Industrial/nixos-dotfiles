# QPS is a simple process manager for LXQT.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    lxqt.qps
  ];
}
