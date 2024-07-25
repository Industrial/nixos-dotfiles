{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    veracrypt
  ];
}
