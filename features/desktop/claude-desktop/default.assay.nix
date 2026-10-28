# Colocated suite: claude-desktop wiring.
#
# The module is three lines, so the suite's job is to pin the two things that can silently
# break: the flake input it imports from, and the fact that the module is actually enabled
# rather than merely imported.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {inputs = {claude-desktop.nixosModules.default = "claude-desktop-module";};};
in
  assay.suite "claude-desktop" {
    importsFlakeModule = assay.eq mod.imports ["claude-desktop-module"];
    importsExactlyOne = assay.eq (builtins.length mod.imports) 1;

    # Importing without enabling is the quiet failure this catches.
    isEnabled = assay.eq mod.programs.claude-desktop.enable true;
  }
