# Nvtop is a GPU process monitor
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nvtopPackages.full
  ];
}
