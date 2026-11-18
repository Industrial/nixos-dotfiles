# Colocated suite for profiles/ai.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./ai.nix;
in
  assay.suite "ai" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;

    # claude-code and cloudcli are a pair: cloudcli is a front end over the state
    # claude-code owns, so an active cloudcli import with claude-code commented out
    # would deploy a UI with nothing behind it.
    importsClaudeCode = assay.eq (builtins.match ".*\n *\\.\\./features/ai/claude-code\n.*" src != null) true;

    # Paseo is the chosen browser surface; cloudcli is the superseded one. These
    # two are mutually exclusive on purpose — both run a daemon watching the same
    # ~/.claude session files — so assert the active one AND that the other stays
    # commented. An uncommented line starts with the path; a commented one does
    # not, which is what the leading-newline-and-spaces anchor distinguishes.
    importsPaseo = assay.eq (builtins.match ".*\n *\\.\\./features/ai/paseo\n.*" src != null) true;
    leavesCloudcliDisabled = assay.eq (builtins.match ".*\n *\\.\\./features/ai/cloudcli\n.*" src != null) false;
    stillMentionsCloudcli = assay.eq (builtins.match ".*# \\.\\./features/ai/cloudcli.*" src != null) true;

    # openhands stays commented here on purpose — hosts/drakkar imports it directly
    # because muninn imports this profile too. See the comment in ai.nix.
    leavesOpenhandsCommented = assay.eq (builtins.match ".*# \\.\\./features/ai/openhands.*" src != null) true;
  }
