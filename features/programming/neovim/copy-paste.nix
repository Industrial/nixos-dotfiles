{...}: {
  # - CopyPaste
  programs.nixvim.keymaps = [
    # Global copy/paste register delete/yank/paste in normal mode.
    {
      mode = "n";
      key = "<leader>d";
      action = "\"+d";
    }
    {
      mode = "n";
      key = "<leader>y";
      action = "\"+y";
    }
    {
      mode = "n";
      key = "<leader>p";
      action = "\"+p";
    }

    # Mouse copy/paste register delete/yank/paste in normal mode.
    {
      mode = "n";
      key = "<leader>D";
      action = "\"*d";
    }
    {
      mode = "n";
      key = "<leader>Y";
      action = "\"*y";
    }
    {
      mode = "n";
      key = "<leader>P";
      action = "\"*p";
    }

    # Global copy/paste register delete/yank/paste in visual mode.
    {
      mode = "v";
      key = "<leader>d";
      action = "\"+d";
    }
    {
      mode = "v";
      key = "<leader>y";
      action = "\"+y";
    }
    {
      mode = "v";
      key = "<leader>p";
      action = "\"+p";
    }

    # Paste from Global Copy/Paste Register in Insert Mode.
    {
      mode = "i";
      key = "<C-v>";
      action = "<esc>\"+pi";
    }
  ];
}
