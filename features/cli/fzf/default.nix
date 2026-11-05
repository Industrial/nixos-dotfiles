# fzf is a fuzzy searcher, use it with CTRL-R in Fish.
# fd, bat and eza ship alongside fzf in profiles/cli-core.nix, so they are on PATH.
{pkgs, ...}: let
  # The scheme, from the one place the fleet keeps it. The import reaches across feature
  # categories because the palette is declared next to the stylix module that selects it;
  # palette.nix depends on builtins only, so this costs nothing and works on a host that
  # never imports profiles/desktop.nix.
  palette = import ./../../window-manager/stylix/palette.nix;
  c = palette.withHash;

  # tinted-theming/tinted-fzf's mapping. Explicit hex rather than ANSI names, because fzf's
  # chrome needs distinctions ANSI cannot express: `gutter` has to match the terminal
  # background exactly or the unselected rows sit in a visible box, and `bg+`/`border` have
  # to be two different near-background greys. Those are base00/base01/base02 -- three
  # values that all collapse onto "black" in a sixteen-colour vocabulary.
  colors =
    "--color=bg+:${c.base01},bg:${c.base00},spinner:${c.base0C},hl:${c.base0D}"
    + " --color=fg:${c.base04},header:${c.base0D},info:${c.base0A},pointer:${c.base0C}"
    + " --color=marker:${c.base0C},fg+:${c.base06},prompt:${c.base0A},hl+:${c.base0D}"
    + " --color=border:${c.base02},gutter:${c.base00}";
in {
  environment = {
    systemPackages = with pkgs; [
      fzf
    ];
    sessionVariables = {
      FZF_DEFAULT_COMMAND = "fd --type f --hidden --exclude .git";
      # Layout, preview and colour. The preview degrades to echoing the line, so non-path
      # candidates (CTRL-R history) still render something.
      FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border --info=inline --preview-window=right:60% --preview '[ -d {} ] && eza --tree --level=2 --colour=always {} || ([ -f {} ] && bat --style=numbers --color=always --line-range :200 {} || echo {})' ${colors}";
    };
  };
}
