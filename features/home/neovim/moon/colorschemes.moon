base16 = () ->
  vim.g.base16colorspace = 256

(() ->
  -- Enables 24-bit RGB color in the TUI.
  vim.opt.termguicolors = true

  base16!

  -- -- Use the the Base16 Shell theme in vim (and Tmux).:we
  -- current_theme_name = os.getenv('BASE16_THEME')
  -- set_theme_path = "$HOME/.config/tinted-theming/set_theme.lua"
  -- is_set_theme_file_readable = vim.fn.filereadable(vim.fn.expand(set_theme_path)) == 1 and true or false
  -- 
  -- if is_set_theme_file_readable then
  --   vim.cmd "source #{set_theme_path}"
  --   vim.cmd "colorscheme base16-#{current_theme_name}"

  -- vim.cmd "colorscheme base16-tomorrow-night"
)!
