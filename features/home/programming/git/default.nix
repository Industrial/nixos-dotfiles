{c9config, pkgs, ...}: {
  programs.git = {
    enable = true;
    userName = c9config.userfullname;
    userEmail = c9config.useremail;
    aliases = {
      a = "add";
      A = "add -A";
      aa = "add -A";
      b = "branch";
      ba = "branch --all";
      bd = "branch -d";
      cb = "checkout -b";
      cm = "commit -m";
      co = "checkout";
      cp = "cherry-pick";
      cpa = "cherry-pick --abort";
      cpc = "cherry-pick --continue";
      d = "diff";
      dc = "diff --cached";
      dt = "difftool -y";
      dtd = "difftool -y --dir-diff";
      f = "fetch -p --all";
      l = "log --oneline --graph --decorate=full";
      la = "log --all --oneline --graph --decorate=full";
      lg = "log";
      m = "merge";
      mt = "mergetool";
      p = "pull";
      pa = "pull -a";
      ps = "push -u";
      psf = "push -u -f";
      psa = "push origin --all";
      rb = "rebase";
      rba = "rebase --abort";
      rbc = "rebase --continue";
      rbs = "rebase --skip";
      rbi = "rebase -i";
      rn = "reset HEAD@{1}";
      rp = "reset HEAD~1";
      rs = "reset";
      rsh = "reset --hard HEAD^";
      rss = "reset --soft HEAD^";
      r = "remote --verbose";
      ru = "remote update -p";
      s = "status";
      sh = "stash";
      t = "tag";
    };
    extraConfig = {
      init = {
        defaultBranch = "main";
      };

      core = {
        mergeoptions = "--no-edit";
      };

      rebase = {
        autoStash = true;
      };

      pull = {
        ff = true;
        rebase = true;
      };

      push = {
        default = "current";
      };

      diff = {
        tool = "meld";
      };

      difftool = {
        prompt = false;
      };

      merge = {
        tool = "meld";
      };

      github = {
        user = "Industrial";
      };
    };
  };

  home.packages = with pkgs; [
    lazygit
  ];
}
