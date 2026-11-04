# Colocated suite for profiles/cli-core.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./cli-core.nix;
  has = feature: builtins.match ".*features/cli/${feature}\n.*" src != null;
in
  assay.suite "cli-core" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;

    # The multiplexer is the load-bearing core entry: an ssh-only host that loses zellij loses
    # every long-running job to a dropped connection.
    carriesMultiplexer = assay.eq (has "zellij") true;

    # Guard the split's direction. calcurse lives in cli-desktop; if it reappears here the
    # boundary has eroded and a headless host is carrying a calendar again.
    carriesNoDesktopOnlyEntry = assay.eq (has "calcurse") false;
  }
