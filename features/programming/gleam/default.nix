{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gleam
  ];
}
