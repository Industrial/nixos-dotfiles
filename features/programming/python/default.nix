{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    python312
  ];
}
