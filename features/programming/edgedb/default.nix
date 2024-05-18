{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    edgedb
  ];
}
