args @ {pkgs, ...}: let
  # dwmOverlay = import ./overlays/my-dwm.nix {inherit pkgs;};
  feature = import ./default.nix args;
in {
  # TODO: Fix this.
  # test_nixpkgs_overlays_dwmOverlay = {
  #   expr = builtins.elem dwmOverlay feature.nixpkgs.overlays;
  #   expected = true;
  # };
  test_environment_systemPackages_slock = {
    expr = builtins.elem pkgs.slock feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_dmenu = {
    expr = builtins.elem pkgs.dmenu feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_dunst = {
    expr = builtins.elem pkgs.dunst feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_picom = {
    expr = builtins.elem pkgs.picom feature.environment.systemPackages;
    expected = true;
  };
  test_home_file_dwm_autostart_sh_source = {
    expr = feature.home.file."dwm/autostart.sh".source;
    expected = ./autostart.sh;
  };
  test_home_file_dwm_autostart_blocking_sh_source = {
    expr = feature.home.file."dwm/autostart_blocking.sh".source;
    expected = ./autostart_blocking.sh;
  };
}
