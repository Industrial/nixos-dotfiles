highlightCursorLine = () ->
  -- Highlight the line the cursor is on.
  vim.opt.cursorline = true

  -- Don"t highlight the column the cursor is on.
  vim.opt.cursorcolumn = false

(() ->
  -- Display a column with signs when necessary.
  -- vim.opt.signcolumn = "auto"
  vim.opt.signcolumn = "auto"

  highlightCursorLine!
)!
