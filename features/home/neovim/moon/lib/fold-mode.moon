defaultFoldMode = () ->
  -- set the fold method to manual
  vim.opt.foldmethod = 'manual'

  -- Remove all folds made by the other fold method.
  vim.cmd('normal zE<cr>')

  -- Set the fold level to 0.
  vim.opt.foldlevelstart = 0

  -- But open all folds at level 1 when opening the file
  vim.opt.foldlevelstart = -1

  -- And do not allow folds below this level
  vim.opt.foldnestmax = 20

  -- Allow one line folds.
  vim.opt.foldminlines = 1

  -- turn on a fold column of 1
  -- TODO: This does not apply correctly.
  vim.opt.foldcolumn = '1'

classFoldMode = () ->
  -- set the fold method to manual
  vim.opt.foldmethod = 'indent'

  -- Set the fold level to 1.
  vim.opt.foldlevel = 1

  -- But open all folds at level 1 when opening the file
  vim.opt.foldlevelstart = 1

  -- And do not allow folds below this level
  vim.opt.foldnestmax = 2

  -- Allow one line folds.
  vim.opt.foldminlines = 0

  -- turn on a fold column of 1
  -- TODO: This does not apply correctly.
  vim.opt.foldcolumn = '3'

functionFoldMode = () ->
  -- set the fold method to manual
  vim.opt.foldmethod = 'indent'

  -- Set the fold level to 0.
  vim.opt.foldlevel = 0

  -- But open all folds at level 1 when opening the file
  vim.opt.foldlevelstart = 0

  -- And do not allow folds below this level
  vim.opt.foldnestmax = 1

  -- Allow one line folds.
  vim.opt.foldminlines = 0

  -- turn on a fold column of 1
  -- TODO: This does not apply correctly.
  vim.opt.foldcolumn = '1'

m =
  defaultFoldMode: defaultFoldMode
  classFoldMode: classFoldMode
  functionFoldMode: functionFoldMode

m
