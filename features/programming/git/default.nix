# Git, configured CLI-first: every tool named here is a terminal program, because half the
# fleet is only ever reached over ssh. The diff/merge tools used to be meld, a GTK app that
# was not even in systemPackages — so `git difftool` failed on every host, silently on the
# headless ones.
#
# Two details worth not rediscovering:
#   - difftastic's binary is `difft` (that is its meta.mainProgram; bin/ holds nothing else).
#     A difftool cmd spelled `difftastic` fails with no error git reports.
#   - the quotes in that cmd are backslash-escaped. Written bare, as upstream's snippet has
#     them, git's own config parser consumes them and stores `difft $LOCAL $REMOTE` — which
#     the shell then word-splits on a path containing a space.
#   - merge.tool is nvimdiff, not difftastic. Difftastic is a differ with no 3-way merge mode,
#     so it cannot be a mergetool at all; nvimdiff is a git built-in and nvim is already the
#     fleet's DIFFPROG (features/cli/{fish,nushell}).
#
# delta (core.pager) and difftastic come from profiles/cli-core.nix, which base.nix imports,
# so they are present wherever this feature is.
{
  settings,
  pkgs,
  ...
}: let
  gitconfigFile = pkgs.writeTextFile {
    name = "gitconfig";
    text = ''
      [user]
        name = ${settings.userfullname}
        email = ${settings.useremail}
      [alias]
        a = add
        aa = add -A
        b = branch
        ba = branch --all
        bd = branch -d
        cb = checkout -b
        cm = commit -m
        co = checkout
        cp = cherry-pick
        cpa = cherry-pick --abort
        cpc = cherry-pick --continue
        d = diff
        dc = diff --cached
        dt = difftool -y
        dtd = difftool -y --dir-diff
        f = fetch -p --all
        l = log
        ll = log --oneline --graph --decorate=full
        la = log --all --oneline --graph --decorate=full
        m = merge
        mt = mergetool
        od = push origin --no-verify -d
        p = pull
        pa = pull -a
        ps = push -u
        psa = push origin --all
        psf = push -u -f
        r = remote --verbose
        rb = rebase
        rba = rebase --abort
        rbc = rebase --continue
        rbi = rebase -i
        rbs = rebase --skip
        rn = reset HEAD@{1}
        rp = reset HEAD~1
        rs = reset
        rsh = reset --hard HEAD^
        rss = reset --soft HEAD^
        ru = remote update -p
        s = status
        st = stash
        t = tag
      [init]
        defaultBranch = main
      [core]
        mergeoptions = --no-edit
        pager = delta
      [interactive]
        diffFilter = delta --color-only
      [delta]
        navigate = true
        side-by-side = true
        # delta's syntax highlighting is bat's, so this defaults to $BAT_THEME -- which
        # features/cli/bat sets to the same value. Declared here anyway, because git runs in
        # contexts that never sourced a login shell (hooks, sudo, editors spawning `git
        # diff`), and in those the default would silently become delta's own.
        #
        # "base16" renders through the terminal's palette rather than its own hex, so this is
        # the gruvbox-dark-hard scheme by way of the ANSI colours
        # features/window-manager/{alacritty,ghostty} emit. delta's plus/minus *backgrounds*
        # are deliberately left at its defaults: base16 offers no dark red or dark green to
        # derive them from, and every in-scheme alternative is worse -- tinted-delta uses
        # base01 for both, which throws away the add/remove distinction, and a
        # foreground-only style throws away the syntax highlighting instead.
        syntax-theme = base16
      [rebase]
        autoStash = true
      [pull]
        ff = true
        rebase = true
      [push]
        default = current
        autoSetupRemote = true
      [fetch]
        prune = true
      [branch]
        sort = -committerdate
      [column]
        ui = auto
      [rerere]
        enabled = true
      [diff]
        tool = difftastic
        algorithm = histogram
        colorMoved = default
      [difftool]
        prompt = false
      [difftool "difftastic"]
        cmd = difft \"$LOCAL\" \"$REMOTE\"
      [merge]
        tool = nvimdiff
        conflictStyle = zdiff3
    '';
  };
in {
  environment.systemPackages = with pkgs; [
    git
  ];
  environment.etc."gitconfig".source = gitconfigFile;
}
