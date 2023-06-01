local defaultFoldMode
defaultFoldMode = function()
  vim.opt.foldmethod = 'manual'
  vim.cmd('normal zE<cr>')
  vim.opt.foldlevelstart = 0
  vim.opt.foldlevelstart = -1
  vim.opt.foldnestmax = 20
  vim.opt.foldminlines = 1
  vim.opt.foldcolumn = '1'
end
local classFoldMode
classFoldMode = function()
  vim.opt.foldmethod = 'indent'
  vim.opt.foldlevel = 1
  vim.opt.foldlevelstart = 1
  vim.opt.foldnestmax = 2
  vim.opt.foldminlines = 0
  vim.opt.foldcolumn = '3'
end
local functionFoldMode
functionFoldMode = function()
  vim.opt.foldmethod = 'indent'
  vim.opt.foldlevel = 0
  vim.opt.foldlevelstart = 0
  vim.opt.foldnestmax = 1
  vim.opt.foldminlines = 0
  vim.opt.foldcolumn = '1'
end
local m = {
  defaultFoldMode = defaultFoldMode,
  classFoldMode = classFoldMode,
  functionFoldMode = functionFoldMode
}
return m
