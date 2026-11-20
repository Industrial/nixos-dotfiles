{...}: {
  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<C-s>";
      action = "<cmd>write<cr>";
    }
  ];
}
