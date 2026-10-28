# Colocated suite: V-268111 — audit directory and logs owned by root, via V-268113/V-268114.
#
# Verifies the coverage claim against the real sibling controls, so "handled elsewhere" cannot
# rot into "handled nowhere".
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268111.nix {};
  ownerOf = p: let
    rule = builtins.head (import p {}).systemd.tmpfiles.rules;
    fields = builtins.filter (f: builtins.isString f && f != "") (builtins.split " +" rule);
  in
    builtins.elemAt fields 3;
  pathOf = p: let
    rule = builtins.head (import p {}).systemd.tmpfiles.rules;
    fields = builtins.filter (f: builtins.isString f && f != "") (builtins.split " +" rule);
  in
    builtins.elemAt fields 1;
in
  assay.suite "stig-V-268111" {
    emitsNothing = assay.eq self {};

    directoryOwnedByRoot = assay.eq (ownerOf ./V-268113.nix) "root";
    logFileOwnedByRoot = assay.eq (ownerOf ./V-268114.nix) "root";

    # The fix text's `chown -R /var/log/audit` covers both paths; confirm both are addressed.
    directoryIsTheAuditDir = assay.eq (pathOf ./V-268113.nix) "/var/log/audit";
    logFileIsUnderIt = assay.eq (pathOf ./V-268114.nix) "/var/log/audit/audit.log";
  }
