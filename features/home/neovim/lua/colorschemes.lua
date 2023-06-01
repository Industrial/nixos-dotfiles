local base16
base16 = function()
  vim.g.base16colorspace = 256
end
return (function()
  vim.opt.termguicolors = true
  return base16()
end)()
