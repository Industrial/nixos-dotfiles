local mouse
mouse = function()
  vim.opt.mouse = "a"
end
local comment
comment = function()
  local nvimComment = require("nvim_comment")
  nvimComment.setup()
  vim.keymap.set("n", "<C-_>", ":CommentToggle<cr>", {
    noremap = true
  })
  vim.keymap.set("n", "<C-/>", ":CommentToggle<cr>", {
    noremap = true
  })
  vim.keymap.set("v", "<C-_>", ":\"<,\">CommentToggle<cr>", {
    noremap = true
  })
  return vim.keymap.set("v", "<C-/>", ":\"<,\">CommentToggle<cr>", {
    noremap = true
  })
end
return (function()
  vim.opt.whichwrap = "b,s,h,l,<,>,[,]"
  vim.opt.backspace = "indent,eol,start"
  vim.opt.scrolloff = 50
  mouse()
  return comment()
end)()
