{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gimp
    gimp-with-plugins
    gimpPlugins.gmic
    # gimpPlugins.fourier  # Marked as broken in nixpkgs
    # gimpPlugins.resynthesizer  # Marked as broken in nixpkgs
    gimpPlugins.lightning
  ];
}
