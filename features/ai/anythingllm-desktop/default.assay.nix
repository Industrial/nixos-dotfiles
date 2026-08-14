# Colocated suite for features/ai/anythingllm-desktop/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "anythingllm-desktop" {
    mentionsSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
  }
