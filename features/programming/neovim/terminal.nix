{...}: {
  # https://github.com/akinsho/toggleterm.nvim
  programs.nixvim.plugins.toggleterm = {
    enable = true;

    settings = {
      open_mapping = "[[<c-t>]]";

      direction = "float";
      float_opts = {
        border = "curved";
      };
    };
  };
}
