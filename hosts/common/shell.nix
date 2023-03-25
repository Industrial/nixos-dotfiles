{pkgs, ...}: {
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;

      autosuggestions = {
        enable = true;
      };

      syntaxHighlighting = {
        enable = true;
      };
    };
  };

  environment = {
    shells = with pkgs; [
      zsh
    ];
  };
}
