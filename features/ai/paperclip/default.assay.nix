# Colocated suite for features/ai/paperclip
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  pkg = builtins.readFile ./package.nix;
in
  assay.suite "paperclip" {
    hasPaperclipaiNet = assay.eq (builtins.match ".*paperclipai\\.net.*" src != null) true;
    hasNodejs22 = assay.eq (builtins.match ".*nodejs_22.*" src != null) true;
    hasCallPackage = assay.eq (builtins.match ".*callPackage.*package\\.nix.*" src != null) true;
    hasWrapperName = assay.eq (builtins.match ".*name = \"paperclipai\".*" pkg != null) true;
    pinsNpmVersion = assay.eq (builtins.match ".*paperclipai@2026\\.817\\.0.*" pkg != null) true;
  }
