let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./program-moon.nix {};
  on = h.feature ./program-moon.nix {local.features.program-moon.enable = true;};
  has = name: names: builtins.elem name names;
in
  assay.suite "program-moon" {
    disabledPackages = assay.eq off.packages [];
    disabledScripts = assay.eq off.scripts [];
    package = assay.eq (has "moon-cli" on.packages) true;
    script = assay.eq (has "moon-sync" on.scripts) true;
    scriptExec = assay.eq (builtins.match ".*moon sync.*" on.scriptExec.moon-sync != null) true;
    enterShell = assay.eq (builtins.match ".*moon-sync.*" on.enterShell != null) true;
  }
