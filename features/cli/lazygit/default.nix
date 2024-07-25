{...}: {
  programs.lazygit = {
    enable = true;

    settings = {
      git = {
        log = {
          showWholeGraph = true;
        };
      };
    };
  };
}
