local highlightCursorLine
highlightCursorLine = function()
  vim.opt.cursorline = true
  vim.opt.cursorcolumn = false
end
return (function()
  vim.opt.signcolumn = "auto"
  return highlightCursorLine()
end)()
