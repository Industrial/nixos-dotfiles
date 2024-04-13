{...}: {
  programs.nixvim.plugins = {
    # - Debug Adapter Protocol
    dap = {
      enable = true;
    };
  };
}