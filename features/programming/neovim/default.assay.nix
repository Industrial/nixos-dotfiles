# Colocated suite for features/programming/neovim/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  inputs = { nixvim.nixosModules.nixvim = ./buffers.nix; };
  pkgs = { xsel = "xsel"; xclip = "xclip"; };
  # Import only asserts shape via read — full module needs nixvim.
  src = builtins.readFile ./default.nix;
in
  assay.suite "neovim" {
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
    mentionsEnable = assay.eq (builtins.match ".*enable = true.*" src != null) true;
  }
