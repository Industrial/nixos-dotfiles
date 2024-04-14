{...}: {
  # Commenting plugin. Use `gcc` or `gbc`.
  programs.nixvim.plugins.comment.enable = true;

  # # Prevents you from using motions and tells you how to fix your behaviour.
  # # Really gives you a hard time.
  # programs.nixvim.plugins.hardtime.enable = true;

  programs.nixvim.extraConfigLua = ''
    local comment = require('Comment')
    comment.setup()
  '';
}
