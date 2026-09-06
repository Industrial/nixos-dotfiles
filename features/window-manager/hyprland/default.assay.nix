# Colocated suite for features/window-manager/hyprland/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  lua = builtins.readFile ./hyprland.lua;
in
  assay.suite "hyprland" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
    installsHyprpolkit = assay.eq (builtins.match ".*hyprpolkitagent.*" src != null) true;
    luaLoadsHostMonitors = assay.eq (builtins.match ".*monitors\\.lua.*" lua != null) true;
    monitorsDrakkar = assay.eq (builtins.match ".*7680x2160.*" (builtins.readFile ./monitors.drakkar.lua) != null) true;
    monitorsHuginn = assay.eq (builtins.match ".*2160x1440.*" (builtins.readFile ./monitors.huginn.lua) != null) true;
    luaHasDwindle = assay.eq (builtins.match ".*layout = \"dwindle\".*" lua != null) true;
  }
