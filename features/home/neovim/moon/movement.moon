mouse = () ->
  -- Make the mouse usable everywhere.
  vim.opt.mouse = "a"

comment = () ->
  nvimComment = require "nvim_comment"
  nvimComment.setup!

  -- Map <C-_> as well as <C-/> because apparently terminals are terrible.
  vim.keymap.set "n", "<C-_>", ":CommentToggle<cr>",
    noremap: true
  vim.keymap.set "n", "<C-/>", ":CommentToggle<cr>",
    noremap: true
  vim.keymap.set "v", "<C-_>", ":\"<,\">CommentToggle<cr>",
    noremap: true
  vim.keymap.set "v", "<C-/>", ":\"<,\">CommentToggle<cr>",
    noremap: true

() ->
  -- make movement keys wrap to the next/previous line
  vim.opt.whichwrap = "b,s,h,l,<,>,[,]"

  -- Fix backspace behaviour
  vim.opt.backspace = "indent,eol,start"

  -- keep a certain number of lines visible (center the cursor, document moves
  -- under it)
  vim.opt.scrolloff = 50

  mouse!
  comment!
