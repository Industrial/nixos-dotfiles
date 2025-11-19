# OpenCode AI Framework.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      opencode
    ];
  };
}
