{pkgs, ...}: {
  fonts = {
    fonts = with pkgs; [
      terminus_font
      terminus_font_ttf
      nerdfonts
    ];
  };
}
