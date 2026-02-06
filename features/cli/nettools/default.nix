{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nettools # Contains netstat
  ];
}
