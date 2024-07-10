# fastfetch is a command-line system information tool.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    fastfetch
  ];
}
