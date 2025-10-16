{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    python312
    uv
    pipx
  ];
}
