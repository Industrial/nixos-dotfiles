{...}: {
  programs.nixvim.extraConfigLua = ''
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        --vim.cmd("Trouble")
        vim.cmd("Neotree filesystem reveal left")
        vim.cmd("wincmd l")
      end,
    })
  '';
}
