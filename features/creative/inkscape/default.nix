{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    inkscape
    # inkscape-extensions
    # svg2png
    # svg2pdf
    # svg2eps
  ];
}
