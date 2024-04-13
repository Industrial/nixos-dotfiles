{...}: {
  # - BufferSearch
  # Ignore case in searches.
  programs.nixvim.opts.ignorecase = true;
  # Don"t ignore case with capitals.
  programs.nixvim.opts.smartcase = true;
  # Highlight searches as you type.
  programs.nixvim.opts.hlsearch = true;
  # Show matches while typing.
  programs.nixvim.opts.incsearch = true;
}