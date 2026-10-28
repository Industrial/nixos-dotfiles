# Colocated suite: V-268119 — loginuid immutable.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268119.nix {};
in
  assay.suite "stig-V-268119" {
    rules = assay.eq mod.security.audit.rules ["--loginuid-immutable"];
    # A control-flag rule, not a syscall rule — it must not be shaped like one.
    isSingleControlFlag = assay.eq (builtins.length mod.security.audit.rules) 1;
  }
