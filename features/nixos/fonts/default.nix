{pkgs, ...}: {
  # fonts.fonts = with pkgs; [
  #   (pkgs.iosevka.override {
  #     set = "term";
  #     privateBuildPlan = {
  #       family = "IosevkaTerm Nerd Font Mono";
  #       design = ["style-regular" "style-bold" "style-italic"];
  #     };
  #   })
  # ];

  fonts.packages = with pkgs; [
    nerd-fonts.terminess-ttf
    nerd-fonts.iosevka
    nerd-fonts.iosevka-term
  ];
}
