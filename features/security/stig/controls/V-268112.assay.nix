# Colocated suite: V-268112 — audit directory and logs group-owned by root.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268112.nix {};
  groupOf = p: let
    rule = builtins.head (import p {}).systemd.tmpfiles.rules;
    fields = builtins.filter (f: builtins.isString f && f != "") (builtins.split " +" rule);
  in
    builtins.elemAt fields 4;
in
  assay.suite "stig-V-268112" {
    emitsNothing = assay.eq self {};

    directoryGroupIsRoot = assay.eq (groupOf ./V-268113.nix) "root";
    logFileGroupIsRoot = assay.eq (groupOf ./V-268114.nix) "root";
  }
