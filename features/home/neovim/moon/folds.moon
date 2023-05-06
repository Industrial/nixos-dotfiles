() ->
  foldMode = require "lib.fold-mode"
  whichkey = require "which-key"

  -- Folds
  vim.opt.foldenable = true

  -- Don"t ignore anything (e.g. comments) when making folds
  vim.opt.foldignore = ""

  whichkey.register {
    F:
      name: "Fold"
      c: { foldMode.classFoldMode, "Class" }
      d: { foldMode.defaultFoldMode, "Default" }
      f: { foldMode.functionFoldMode, "Function" }
  }, {
    prefix: "<leader>"
  }

  foldMode.defaultFoldMode!
