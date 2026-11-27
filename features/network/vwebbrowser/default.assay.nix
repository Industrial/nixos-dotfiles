# Colocated suite for features/network/vwebbrowser: the crate it installs, its desktop
# entry, and the search engine it is configured with, with SearXNG on and off.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  # Stubbed pkgs: which package file the feature calls, and with what.
  stub = {
    callPackage = path: args: {inherit path args;};
    makeDesktopItem = args: {desktopItem = args;};
    formats.toml = _: {generate = name: value: {inherit name value;};};
  };
  stubbed =
    (import ./default.nix {
      pkgs = stub;
      config = {};
    }).environment.systemPackages;
  crates = builtins.filter (p: p ? path) stubbed;

  # The real module, evaluated: alone (searx off), and next to the real searx feature with
  # the switch its feature wrapper declares turned on.
  without = nixos.eval {modules = [./default.nix];};
  withSearx = nixos.eval {
    modules = [
      ./default.nix
      ../searx/default.nix
      {options.features.network.searx.enable = lib.mkOption {default = true;};}
    ];
  };

  browsers = cfg: builtins.filter (p: (p.pname or "") == "vwebbrowser") cfg.environment.systemPackages;
  desktopFiles = cfg: builtins.filter (p: lib.getName p == "vwebbrowser.desktop") cfg.environment.systemPackages;
  # Read from the derivations' attributes, not their outputs: no import-from-derivation.
  # formats.toml's generate keeps the attrset as `value`; writeTextFile keeps `text`.
  generated = cfg: cfg.environment.etc."xdg/vwebbrowser/config.toml".source.value;
  desktopLines = lib.splitString "\n" (builtins.head (desktopFiles without)).text;
  hasLine = l: builtins.elem l desktopLines;
in
  assay.suite "network-vwebbrowser" {
    installsTheCrate = assay.eq (map (p: p.path) crates) [../../../rust/tools/vwebbrowser/default.nix];
    noOverrides = assay.eq (map (p: p.args) crates) [{}];

    inSystemPackages = assay.eq (builtins.length (browsers without)) 1;
    providesTheBinary = assay.eq (map (p: p.meta.mainProgram) (browsers without)) ["vwebbrowser"];

    # The desktop entry: installed, launching the binary with the URL, offered for web links.
    desktopItemInstalled = assay.eq (builtins.length (desktopFiles without)) 1;
    desktopItemExec = assay.eq (hasLine "Exec=vwebbrowser %u") true;
    desktopItemCategories = assay.eq (hasLine "Categories=Network;WebBrowser") true;
    desktopItemMimeTypes = assay.eq (hasLine "MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https") true;

    # User ruling R2: the local SearXNG when the searx feature is on, on its own port.
    searxTemplate = assay.eq (generated withSearx) {search_template = "http://localhost:4001/search?q={query}";};
    searxPortFollowsTheService =
      assay.eq (generated withSearx).search_template
      "http://localhost:${toString withSearx.services.searx.settings.server.port}/search?q={query}";
    duckDuckGoWithoutSearx = assay.eq (generated without) {search_template = "https://duckduckgo.com/?q={query}";};

    # Not a take-over (plan D5): librewolf stays the default browser.
    noMimeDefaults = assay.eq without.xdg.mime.defaultApplications nixos.baseline.xdg.mime.defaultApplications;
    noMimeDefaultsWithSearx = assay.eq withSearx.xdg.mime.defaultApplications nixos.baseline.xdg.mime.defaultApplications;
  }
