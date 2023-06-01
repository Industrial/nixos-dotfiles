return (function()
  local bufferline = require("bufferline")
  return bufferline.setup({
    options = {
      mode = "buffers",
      diagnostics = "nvim_lsp",
      offsets = {
        filetype = "NvimTree",
        text = "File Explorer",
        highlight = "Directory",
        separator = true
      }
    }
  })
end)()
