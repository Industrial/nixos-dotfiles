{ pkgs, config, ... }:

{
  programs.tmux = {
    aggressiveResize = false;
    baseIndex = 1;
    clock24 = true;
    customPaneNavigationAndResize = false;
    disableConfirmationPrompt = false;
    enable = true;
    escapeTime = 500;
    extraConfig = ''
      set -g mouse on
      set -g focus-events on
      set-option -sg escape-time 10
    '';
    historyLimit = 99999;
    keyMode = "vi";
    newSession = false;
    package = pkgs.tmux;
    prefix = "C-a";
    resizeAmount = 10;
    reverseSplit = false;
    secureSocket = false;
    sensibleOnTop = true;
    #shell = ${pkgs.zsh}/bin/zsh;
    terminal = "tmux-256color";
    tmuxinator = {
      enable = false;
    };

    plugins = with pkgs; [
      { plugin = tmuxPlugins.yank; }
      { plugin = tmuxPlugins.pain-control; }
    ];
  };
}
