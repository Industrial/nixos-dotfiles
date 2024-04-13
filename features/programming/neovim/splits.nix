{...}: {
  programs.nixvim.plugins.smart-splits = {
    enable = true;
  };

  # Splitting a window horizontally (:split) will put the new window below the current one.
  programs.nixvim.opts.splitbelow = true;

  # Splitting a window vertically (:vsplit) will put the new window to the right of the current one.
  programs.nixvim.opts.splitright = true;

  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
    }
  ];
}