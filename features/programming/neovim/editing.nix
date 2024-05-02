{...}: {
  programs.nixvim.plugins = {
    # Automatically close brackets, braces, etc.
    autoclose.enable = true;

    # Automatically add end signals like 'end' or 'endfunction'.
    endwise.enable = true;
  };
}
