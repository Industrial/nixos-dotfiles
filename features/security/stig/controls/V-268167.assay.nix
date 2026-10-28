# Colocated suite: V-268167 — identity databases watched.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268167.nix {};
  rules = mod.security.audit.rules;
in
  assay.suite "stig-V-268167" {
    rules = assay.eq rules [
      "-w /etc/sudoers -p wa -k identity"
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/gshadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/security/opasswd -p wa -k identity"
    ];
    ruleCount = assay.eq (builtins.length rules) 6;

    # All six are write+attribute watches under the identity key; a read watch here would
    # flood the log, and a missing -p would watch nothing useful.
    allAreWriteAttrWatches = assay.eq (builtins.all (r: builtins.match "-w /etc/.* -p wa -k identity" r != null) rules) true;

    # shadow and gshadow are the two most important and the easiest to omit.
    watchesShadow = assay.eq (builtins.elem "-w /etc/shadow -p wa -k identity" rules) true;
    watchesGshadow = assay.eq (builtins.elem "-w /etc/gshadow -p wa -k identity" rules) true;
  }
