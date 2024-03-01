local foldMode = require('lib.fold-mode')
local classFound = vim.fn['search']('class ')
if classFound > 0 then
  foldMode.classFoldMode()
else
  foldMode.functionFoldMode()
end
