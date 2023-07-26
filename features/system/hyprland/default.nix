{pkgs, ...}: {
  programs.hyprland = {
    enable = true;

    #package = inputs.hyprland.packages.${pkgs.system}.default;
    #xwayland = {
    #  enable = true;
    #  hidpi = false;
    #};
    #nvidiaPatches = false;
  };

  environment.systemPackages = with pkgs; [
    kitty
  ];
}
