# Colocated suite for features/ai/paperclip/package.nix.
# Asserts on the evaluated writeShellApplication: its name, its node runtime, and the
# generated script (`text`, the artifact) — root guard, pinned version, passthrough.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;
  # Substring test over generated text; store-path context is irrelevant to the match.
  contains = needle: s: lib.hasInfix (builtins.unsafeDiscardStringContext needle) (builtins.unsafeDiscardStringContext s);
  pkgs = (nixos.evalSystem {modules = [];}).pkgs;
  drv = pkgs.callPackage ./package.nix {};
  script = drv.text;
in
  assay.suite "paperclip-package" {
    namesCliPaperclipai = assay.eq drv.name "paperclipai";
    exposesPaperclipaiAsMainProgram = assay.eq drv.meta.mainProgram "paperclipai";
    runsViaNode22 = assay.eq (contains "export PATH=\"${pkgs.nodejs_22}/bin:$PATH\"" script) true;
    rejectsRoot = assay.eq (contains "do not run as root (embedded Postgres)" script) true;
    pinsPackageVersion = assay.eq (contains "npx --yes paperclipai@2026.817.0 " script) true;
    execPassthrough = assay.eq (contains "exec npx --yes paperclipai@2026.817.0 \"$@\"" script) true;
  }
