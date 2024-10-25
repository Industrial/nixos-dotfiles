{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nodejs_22
    corepack_22
  ];
}
