{
  settings,
  pkgs,
  ...
}: {
  programs.alacritty.enable = true;

  programs.alacritty.settings = {
    font = pkgs.lib.mkForce {
      normal = {
        family = "IosevkaTerm Nerd Font Mono";
        style = "Regular";
      };
      bold = {
        style = "Bold";
      };
      italic = {
        style = "Italic";
      };

      size = 12.0;
    };
  };
}
