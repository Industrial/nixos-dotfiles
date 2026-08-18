# Colocated suite for features/window-manager/hyprland/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  lua = builtins.readFile ./hyprland.lua;
  shell = builtins.readFile ./caelestia/shell.json;
in
  assay.suite "hyprland" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
    hasCaelestiaGuard = assay.eq (builtins.match ".*hasCaelestia.*" src != null) true;
    installsHyprpolkit = assay.eq (builtins.match ".*hyprpolkitagent.*" src != null) true;
    luaUsesCaelestia = assay.eq (builtins.match ".*caelestia-shell.*" lua != null) true;
    luaHasMaster = assay.eq (builtins.match ".*master.*" lua != null) true;
    shellIdleConfigured = assay.eq (builtins.match ".*lockBeforeSleep.*" shell != null) true;
    shellWallpaperDir = assay.eq (builtins.match ".*Wallpapers.*" shell != null) true;
  }
