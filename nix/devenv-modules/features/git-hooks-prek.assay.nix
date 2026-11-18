let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./git-hooks-prek.nix {};
  on = h.feature ./git-hooks-prek.nix {local.features.git-hooks-prek.enable = true;};
  custom = h.feature ./git-hooks-prek.nix {
    local.features.git-hooks-prek = {
      enable = true;
      configFile = "custom-hooks.yaml";
    };
  };
in
  assay.suite "git-hooks-prek" {
    disabled = assay.eq off.git-hooks {};
    hasPackage = assay.eq (on.git-hooks ? package) true;
    commitizen = assay.eq on.git-hooks.hooks.commitizen.enable true;
    preCommitHook = assay.eq on.git-hooks.hooks.pre-commit.enable true;
    prePushHook = assay.eq on.git-hooks.hooks.pre-push.enable true;
    stages = assay.eq on.git-hooks.default_stages ["pre-push" "commit-msg"];
    installScript = assay.eq (builtins.elem "install-git-hooks" on.scripts) true;
    installMentionsDefaultCfg = assay.eq (builtins.match ".*\\.pre-commit-config\\.yaml.*" on.scriptExec.install-git-hooks != null) true;
    customCfg = assay.eq (builtins.match ".*custom-hooks\\.yaml.*" custom.scriptExec.install-git-hooks != null) true;
    enterShell = assay.eq (builtins.match ".*install-git-hooks.*" on.enterShell != null) true;
  }
