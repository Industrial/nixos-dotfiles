{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    xsel
  ];
}
