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
      [rebase]
        autoStash = true
      [pull]
        ff = true
        rebase = true
      [push]
        default = current
      [diff]
        tool = meld
      [difftool]
        prompt = false
      [merge]
        tool = meld
    '';
  };
in {
  environment.systemPackages = with pkgs; [
    git
  ];
  environment.etc."gitconfig".source = gitconfigFile;
}
