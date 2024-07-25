# QPS is a simple process manager for LXQT.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lxqt.qps
  ];
}
