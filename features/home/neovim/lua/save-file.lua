local indentationGuides
indentationGuides = function()
  local indentBlankline = require("indent_blankline")
  return indentBlankline.setup({
    show_current_context = true,
    show_current_context_start = true
  })
end
return (function()
  vim.keymap.set("n", "<C-s>", ":write<cr>", { })
  vim.keymap.set("i", "<C-s>", "<esc>:write<cr>a", { })
  return indentationGuides()
end)()
