# Assay: Hyprland from its flake input, the desktop plumbing around it, and its Lua config.
#
# Module claims read the evaluated config (hyprland comes from the root flake's `hyprland`
# input via nixos.nix's resolver, as on a host). The Lua files are the artifact Hyprland
# loads, so they are matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {
    modules = [./default.nix];
    settings.hostname = "drakkar";
  };
  user = nixos.defaultSettings.username;
  hyprInput = nixos.flakeInputs.hyprland.packages.x86_64-linux;
  hl = cfg.programs.hyprland;
  activation = cfg.system.activationScripts.hyprland-config.text;
  activationHas = needle: lib.hasInfix needle activation;
  etc = cfg.environment.etc;
  lua = builtins.readFile ./hyprland.lua;
in
  assay.suite "hyprland" {
    enablesHyprland = assay.eq hl.enable true;
    # Lua configs need Hyprland 0.55+, so the package is the flake input's, not nixpkgs'.
    packageFromFlakeInput = assay.eq hl.package.drvPath hyprInput.hyprland.drvPath;
    portalFromFlakeInput = assay.eq hl.portalPackage.drvPath hyprInput.xdg-desktop-portal-hyprland.drvPath;
    xwaylandOn = assay.eq hl.xwayland.enable true;
    gdmLogin = assay.eq cfg.services.displayManager.gdm.enable true;

    installsHyprpolkit = assay.eq (nixos.hasPackage cfg "hyprpolkitagent") true;
    polkitEnabled = assay.eq cfg.security.polkit.enable true;
    installsScreenshotAndClipboardTools =
      assay.eq (map (nixos.hasPackage cfg) ["grim" "slurp" "swappy" "cliphist" "wl-clipboard"]) [true true true true true];
    installsBarAndLauncher = assay.eq (map (nixos.hasPackage cfg) ["ashell" "hyprlauncher"]) [true true];

    # xdg-desktop-portal-wlr alongside Hyprland's portal races it for ScreenCast and breaks
    # Signal/WebRTC sharing (black remote).
    wlrPortalOff = assay.eq cfg.xdg.portal.wlr.enable false;
    gtkPortalForFilePickers =
      assay.eq (builtins.elem "xdg-desktop-portal-gtk" (map lib.getName cfg.xdg.portal.extraPortals)) true;

    # Fallback configs in /etc/xdg/hypr, from the committed files.
    shipsFallbackLuaConfig = assay.eq {inherit (etc."xdg/hypr/hyprland.lua") source mode;} {
      source = ./hyprland.lua;
      mode = "0644";
    };
    shipsFallbackPortalConfig = assay.eq etc."xdg/hypr/xdph.conf".source ./xdph.conf;

    # The live config is the mutable checkout, so edits apply on reload without a rebuild; the
    # host's monitors file is picked by hostname, falling back to monitors.default.lua.
    linksLiveLuaConfig =
      assay.eq (activationHas ''ln -sfn "${nixos.defaultSettings.userdir}/.dotfiles/features/window-manager/hyprland/hyprland.lua" /home/${user}/.config/hypr/hyprland.lua'') true;
    picksHostMonitorsFile = assay.eq (activationHas "/monitors.drakkar.lua\"") true;
    fallsBackToDefaultMonitors = assay.eq (activationHas "/monitors.default.lua\"") true;

    # Aquamarine pinned to card1, drakkar's discrete GPU. Note it is set for EVERY host that
    # imports this feature, not only drakkar (huginn has a single Intel iGPU).
    aquamarineOnDiscreteGpu = assay.eq cfg.environment.sessionVariables.AQ_DRM_DEVICES "/dev/dri/card1";
    waylandBackends =
      assay.eq (with cfg.environment.sessionVariables; [QT_QPA_PLATFORM GDK_BACKEND]) ["wayland" "wayland"];

    wallpaperRotatesEvery15Min = assay.eq {inherit (cfg.systemd.user.timers.awww-random.timerConfig) OnBootSec OnUnitActiveSec;} {
      OnBootSec = "15min";
      OnUnitActiveSec = "15min";
    };

    luaLoadsHostMonitors = assay.eq (lib.hasInfix ''"/.config/hypr/monitors.lua"'' lua) true;
    monitorsDrakkar = assay.eq (lib.hasInfix "7680x2160" (builtins.readFile ./monitors.drakkar.lua)) true;
    monitorsHuginn = assay.eq (lib.hasInfix "2160x1440" (builtins.readFile ./monitors.huginn.lua)) true;
    luaHasDwindle = assay.eq (lib.hasInfix ''layout = "dwindle"'' lua) true;

    # vfiles (GH-188): every file the script linked, from the checkout, each with its
    # committed copy as the fallback (hyprsunset.conf: the /etc copy, as before); drakkar's
    # own monitor layout.
    vfilesDeclaresEveryLink = assay.eq (builtins.attrNames cfg.vfiles.files) (map (r: "${nixos.defaultSettings.userdir}/.config/${r}") [
      "ashell/config.toml"
      "hypr/hyprland.conf.hyprlang"
      "hypr/hyprland.lua"
      "hypr/hyprlock.conf"
      "hypr/hyprsunset.conf"
      "hypr/hyprtoolkit.conf"
      "hypr/monitors.lua"
      "hypr/xdph.conf"
    ]);
    vfilesLinksTheCheckoutWithAFallback = let
      f = cfg.vfiles.files."${nixos.defaultSettings.userdir}/.config/hypr/hyprland.lua";
    in
      assay.eq [f.source (f.fallback == ./hyprland.lua)] ["${nixos.defaultSettings.userdir}/.dotfiles/features/window-manager/hyprland/hyprland.lua" true];
    vfilesPicksTheHostMonitors =
      assay.eq (lib.hasSuffix "/monitors.drakkar.lua" cfg.vfiles.files."${nixos.defaultSettings.userdir}/.config/hypr/monitors.lua".source) true;
    vfilesEveryCheckoutLinkHasAFallback =
      assay.eq (lib.all (f: f.fallback != null) (lib.filter (f: lib.hasPrefix "${nixos.defaultSettings.userdir}/.dotfiles/" f.source) (builtins.attrValues cfg.vfiles.files))) true;
  }
