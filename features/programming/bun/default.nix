{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    bun
  ];
}
