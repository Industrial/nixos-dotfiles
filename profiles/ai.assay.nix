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
    importsCloudcli = assay.eq (builtins.match ".*\n *\\.\\./features/ai/cloudcli\n.*" src != null) true;

    # openhands stays commented here on purpose — hosts/drakkar imports it directly
    # because muninn imports this profile too. See the comment in ai.nix.
    leavesOpenhandsCommented = assay.eq (builtins.match ".*# \\.\\./features/ai/openhands.*" src != null) true;
  }
