{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gimp
    gimp-with-plugins
    gimpPlugins.gmic
    gimpPlugins.fourier
    gimpPlugins.resynthesizer
    gimpPlugins.lightning
  ];
}
