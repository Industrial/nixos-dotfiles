# Colocated suite for features/ai/paperclip/package.nix.
# String-level guards (repo pattern): root guard, node runtime, pinned version.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
in
  assay.suite "paperclip-package" {
    namesCliPaperclipai =
      assay.eq (builtins.match ".*name = \"paperclipai\";.*" src != null) true;
    runsViaNode22 =
      assay.eq
        (builtins.match ".*runtimeInputs = [[]nodejs_22[]];.*" src != null)
        true;
    rejectsRoot =
      assay.eq
        (builtins.match ".*do not run as root \\(embedded Postgres\\).*" src != null)
        true;
    pinsPackageVersion =
      assay.eq (builtins.match ".*paperclipai@2026\\.817\\.0.*" src != null) true;
    execPassthrough =
      assay.eq (builtins.match ".*exec npx[^\n]*\"\\$@\".*" src != null) true;
  }
