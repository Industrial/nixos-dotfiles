{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gimp
    gimp-with-plugins
    gimpPlugins.gmic
    gimpPlugins.fourier
    gimpPlugins.resynthesizer
    gimpPlugins.gap
    gimpPlugins.fractal-explorer
    gimpPlugins.gfig
    gimpPlugins.lightning
    gimpPlugins.maze
    gimpPlugins.mosaic
    gimpPlugins.noise
    gimpPlugins.panorama
    gimpPlugins.polar-coords
    gimpPlugins.ripple
    gimpPlugins.screen-shot
    gimpPlugins.seamless
    gimpPlugins.sky
    gimpPlugins.sparkle
    gimpPlugins.twain
    gimpPlugins.wave
    gimpPlugins.web-browser
    gimpPlugins.xjt
  ];
}
