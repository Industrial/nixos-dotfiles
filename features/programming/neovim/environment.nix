{...}: {
  programs = {
    nixvim = {
      plugins = {
        # Automatically load the direnv (NixOS) environment. This is handy
        # because you can call external programs from vim that have been set up
        # by direnv.
        direnv = {
          enable = true;
        };
      };
    };
  };
}
