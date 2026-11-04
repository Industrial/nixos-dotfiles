# fzf is a fuzzy searcher, use it with CTRL-R in Fish.
# fd, bat and eza ship alongside fzf in profiles/cli-core.nix, so they are on PATH.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      fzf
    ];
    sessionVariables = {
      FZF_DEFAULT_COMMAND = "fd --type f --hidden --exclude .git";
      # Layout and preview only: no colour flags, stylix owns the palette.
      # The preview degrades to echoing the line, so non-path candidates
      # (CTRL-R history) still render something.
      FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border --info=inline --preview-window=right:60% --preview '[ -d {} ] && eza --tree --level=2 --colour=always {} || ([ -f {} ] && bat --style=numbers --color=always --line-range :200 {} || echo {})'";
    };
  };
}
