# Matrix.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    fractal
  ];
}
