{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    hyper
  ];
}
