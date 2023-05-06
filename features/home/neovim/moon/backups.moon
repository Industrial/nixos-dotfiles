backupFiles = () ->
  -- Make backups.
  vim.opt.backup = true

  -- Make a backup before overwriting a file.
  vim.opt.writebackup = true

  -- Directory to keep backup files in.
  vim.opt.backupdir = vim.fn.expand "~/.config/nvim/backup"

  -- When writing a file and a backup is made, make a copy of the file and overwrite the original.
  vim.opt.backupcopy = "yes"

swapFiles = () ->
  -- Use swap files.
  vim.opt.swapfile = true

  -- Directory to put swap files in.
  vim.opt.directory = vim.fn.expand "~/.config/nvim/temp"

undoFiles = () ->
  -- Use undo files.
  vim.opt.undofile = true

  -- Directory to put undo files in.
  vim.opt.undodir = vim.fn.expand "~/.config/nvim/undo"

() ->
  backupFiles!
  swapFiles!
  undoFiles!
