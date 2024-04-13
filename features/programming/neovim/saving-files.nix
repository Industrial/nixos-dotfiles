{...}: {
  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<C-s>";
      action = "<cmd>write<cr>";
    }
    # {
    #   mode = "i";
    #   key = "<C-s>";
    #   action = "<esc><cmd>write<cr>i";
    # }
  ];
}