local backupFiles
backupFiles = function()
  vim.opt.backup = true
  vim.opt.writebackup = true
  vim.opt.backupdir = vim.fn.expand("~/.config/nvim/backup")
  vim.opt.backupcopy = "yes"
end
local swapFiles
swapFiles = function()
  vim.opt.swapfile = true
  vim.opt.directory = vim.fn.expand("~/.config/nvim/temp")
end
local undoFiles
undoFiles = function()
  vim.opt.undofile = true
  vim.opt.undodir = vim.fn.expand("~/.config/nvim/undo")
end
return (function()
  backupFiles()
  swapFiles()
  return undoFiles()
end)()
