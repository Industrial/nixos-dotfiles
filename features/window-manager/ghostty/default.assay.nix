# Colocated suite: ghostty on systemPackages, plus the declared config.
let
  assay = import ./../../../common/assay/default.nix;
  # `writeTextFile = args: args.name` keeps the activation `.text` forceable
  # without a real nixpkgs: the stub must cover every pkgs attribute the text
  # interpolates, which here is writeTextFile and nothing else.
  pkgs = {
    ghostty = "ghostty";
    writeTextFile = args: args.name;
  };
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
    inherit pkgs;
  };
  activation = mod.system.activationScripts.linkGhosttyConfig.text;

  # Ghostty's config is "key = value", not TOML, so there is no fromTOML to
  # lean on -- parse it here instead, and let a line that does not parse fail
  # the suite at eval rather than silently at the first launch.
  raw = builtins.readFile ./.config/ghostty/config.ghostty;
  allLines = builtins.filter builtins.isString (builtins.split "\n" raw);
  # Blank lines and `#` comments are ignored by ghostty(5).
  settingLines = builtins.filter (l: builtins.match " *(#.*)?" l == null) allLines;
  lineRe = " *([a-z0-9-]+) *= *(.*)";
  pairs =
    map (l: let
      m = builtins.match lineRe l;
    in {
      key = builtins.elemAt m 0;
      value = builtins.elemAt m 1;
    })
    settingLines;
  keys = map (p: p.key) pairs;
  values = map (p: p.value) pairs;
  # Ghostty allows a key to repeat; take every occurrence so a later duplicate
  # cannot hide behind the first.
  get = k: map (p: p.value) (builtins.filter (p: p.key == k) pairs);

  # The monospace family is owned by stylix. Read the literal out of that file
  # rather than restating it, so the two cannot drift apart silently.
  stylixMonospace =
    builtins.head
    (builtins.match ".*monospace = \\{[^}]*name = \"([^\"]+)\";.*"
      (builtins.readFile ./../stylix/default.nix));
  # alacritty.toml is the third copy of the same literal.
  alacrittyMonospace =
    (builtins.fromTOML
      (builtins.readFile ./../alacritty/.config/alacritty/alacritty.toml))
    .font
    .normal
    .family;

  # Colour keys belong to features/window-manager/stylix. Any of these
  # appearing here would fork the base16 scheme.
  colourKeys = [
    "theme"
    "background"
    "foreground"
    "palette"
    "cursor-color"
    "selection-background"
    "selection-foreground"
    "split-divider-color"
    "unfocused-split-fill"
  ];
in
  assay.suite "ghostty" {
    packages = assay.eq mod.environment.systemPackages ["ghostty"];

    activationScriptDeclared =
      assay.eq (mod.system.activationScripts ? linkGhosttyConfig) true;
    # `linkFile` belongs to alacritty; a second definition collides on eval.
    doesNotClaimGenericLinkFile =
      assay.eq (mod.system.activationScripts ? linkFile) false;
    createsConfigDir =
      assay.eq
      (builtins.match ".*mkdir -p /home/alice/[.]config/ghostty.*" activation
        != null)
      true;
    # ghostty(5) 1.4.0 loads $XDG_CONFIG_HOME/ghostty/config.ghostty; the
    # extensionless legacy `config` still works but is not the documented path.
    linksConfigGhostty =
      assay.eq
      (builtins.match
        ".*ln -sf config[.]ghostty /home/alice/[.]config/ghostty/config[.]ghostty.*"
        activation
        != null)
      true;

    everySettingLineParses =
      assay.eq
      (builtins.all (l: builtins.match lineRe l != null) settingLines)
      true;
    configIsNotEmpty = assay.eq (builtins.length pairs > 0) true;

    # The font literal must agree with stylix, which alacritty also duplicates.
    fontMatchesStylix = assay.eq (get "font-family") [stylixMonospace];
    stylixAndAlacrittyAgree = assay.eq alacrittyMonospace stylixMonospace;

    # Ligatures are the reason ghostty sits beside alacritty. IosevkaTerm
    # carries its ligature set in `calt` and ships no `liga` feature, so `calt`
    # is the only setting that does anything here.
    ligaturesEnabled = assay.eq (get "font-feature") ["calt"];
    ligaturesNotDisabled =
      assay.eq
      (builtins.all (v: builtins.match "-calt|calt (off|=0)" v == null)
        (get "font-feature"))
      true;

    # Wave 7's leaf-stylix-terminal owns the palette; stay out of its way.
    paletteStaysNeutral =
      assay.eq (builtins.all (k: !(builtins.elem k colourKeys)) keys) true;
    noHexLiterals =
      assay.eq (builtins.all (v: builtins.match ".*#.*" v == null) values) true;

    # Presentation matched to alacritty.toml.
    opacityMatchesAlacritty = assay.eq (get "background-opacity") ["0.85"];
    paddingMatchesAlacritty =
      assay.eq (get "window-padding-x" ++ get "window-padding-y") ["8" "8"];
  }
