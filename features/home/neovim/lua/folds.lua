return (function()
  local foldMode = require("lib.fold-mode")
  local whichkey = require("which-key")
  vim.opt.foldenable = true
  vim.opt.foldignore = ""
  whichkey.register({
    F = {
      name = "Fold",
      c = {
        foldMode.classFoldMode,
        "Class"
      },
      d = {
        foldMode.defaultFoldMode,
        "Default"
      },
      f = {
        foldMode.functionFoldMode,
        "Function"
      }
    }
  }, {
    prefix = "<leader>"
  })
  return foldMode.defaultFoldMode()
end)()
