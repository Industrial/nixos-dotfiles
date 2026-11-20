# Assay: ghostty on systemPackages, plus the config it links into place.
#
# Claims read the evaluated config. The file ghostty actually loads is a store file the
# activation script links to ~/.config/ghostty/config.ghostty; the suite reads that file back
# (IFD is fine in a suite) and parses it. It is the committed config.ghostty plus a generated
# colour block. Everything below named `committed*` is about the first half, read straight
# from the repo; the `generated*` cases are about the second. Keeping them apart is what lets
# the neutrality tripwires survive: the hand-written file must still carry no colour, because
# the only sanctioned way to change the scheme is features/window-manager/stylix/palette.nix.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  home = nixos.defaultSettings.userdir;
  activation = cfg.system.activationScripts.linkGhosttyConfig.text;

  palette = import ../stylix/palette.nix;

  # Ghostty's config is "key = value", not TOML, so there is no fromTOML to lean on -- parse
  # it here instead, and let a line that does not parse fail the suite at eval rather than
  # silently at the first launch. Blank lines and `#` comments are ignored by ghostty(5).
  lineRe = " *([a-z0-9-]+) *= *(.*)";
  settingLinesOf = text:
    builtins.filter (l: builtins.match " *(#.*)?" l == null)
    (builtins.filter builtins.isString (builtins.split "\n" text));
  pairsOf = text:
    map (l: let
      m = builtins.match lineRe l;
    in {
      key = builtins.elemAt m 0;
      value = builtins.elemAt m 1;
    })
    (settingLinesOf text);
  # Ghostty allows a key to repeat; take every occurrence so a later duplicate cannot hide
  # behind the first.
  getFrom = pairs: k: map (p: p.value) (builtins.filter (p: p.key == k) pairs);

  linkedPath = builtins.match ".*ln -sf (/nix/store/[^ ]+-config[.]ghostty) ${home}/[.]config/ghostty/config[.]ghostty\n.*" activation;
  # builtins.match drops string context, and a store path without context is never built, so
  # readFile only worked where the file was already in the store (never on a fresh CI
  # runner). Re-attach the context of the derivation that produces the matched path.
  realised = path:
    builtins.appendContext path (lib.filterAttrs
      (drv: _: lib.hasSuffix "-${builtins.substring 33 (-1) (baseNameOf path)}.drv" drv)
      (builtins.getContext activation));
  generatedConfig = builtins.readFile (realised (builtins.head linkedPath));
  generatedPairs = pairsOf generatedConfig;
  generatedGet = getFrom generatedPairs;
  # `palette = N=#rrggbb`, which ghostty accumulates rather than replaces.
  paletteSlots =
    map (v: let
      m = builtins.match "([0-9]+)=(#[0-9a-f]{6})" v;
    in {
      index = builtins.elemAt m 0;
      color = builtins.elemAt m 1;
    })
    (generatedGet "palette");

  raw = builtins.readFile ./.config/ghostty/config.ghostty;
  settingLines = settingLinesOf raw;
  pairs = pairsOf raw;
  keys = map (p: p.key) pairs;
  values = map (p: p.value) pairs;
  get = getFrom pairs;

  # The monospace family is owned by stylix: read it from the evaluated stylix option rather
  # than restating it, so the copies cannot drift apart silently.
  stylixMonospace =
    (nixos.eval {
      modules = [nixos.flakeInputs.stylix.nixosModules.stylix ../stylix/default.nix];
    })
    .stylix
    .fonts
    .monospace
    .name;
  # alacritty.toml is the third copy of the same literal.
  alacrittyMonospace =
    (builtins.fromTOML
      (builtins.readFile ../alacritty/.config/alacritty/alacritty.toml))
    .font
    .normal
    .family;

  # Colour keys belong to features/window-manager/stylix. Any of these appearing in the
  # committed file would fork the base16 scheme.
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
    # ghostty and nothing else.
    packages =
      assay.eq (lib.subtractLists (nixos.packageNames nixos.baseline) (nixos.packageNames cfg)) ["ghostty"];

    activationScriptDeclared = assay.eq (cfg.system.activationScripts ? linkGhosttyConfig) true;
    # `linkFile` belongs to alacritty; a second definition collides on eval.
    doesNotClaimGenericLinkFile = assay.eq (cfg.system.activationScripts ? linkFile) false;
    createsConfigDir = assay.eq (lib.hasInfix "mkdir -p ${home}/.config/ghostty\n" activation) true;
    # ghostty(5) 1.4.0 loads $XDG_CONFIG_HOME/ghostty/config.ghostty; the extensionless legacy
    # `config` still works but is not the documented path.
    linksConfigGhostty = assay.eq (linkedPath != null) true;

    everySettingLineParses =
      assay.eq (builtins.all (l: builtins.match lineRe l != null) settingLines) true;
    everyGeneratedLineParses =
      assay.eq (builtins.all (l: builtins.match lineRe l != null) (settingLinesOf generatedConfig)) true;
    configIsNotEmpty = assay.eq (builtins.length pairs > 0) true;

    # The font literal must agree with stylix, which alacritty also duplicates.
    fontMatchesStylix = assay.eq (get "font-family") [stylixMonospace];
    stylixAndAlacrittyAgree = assay.eq alacrittyMonospace stylixMonospace;

    # Ligatures are the reason ghostty sits beside alacritty. IosevkaTerm carries its ligature
    # set in `calt` and ships no `liga` feature, so `calt` is the only setting that does
    # anything here.
    ligaturesEnabled = assay.eq (get "font-feature") ["calt"];
    ligaturesNotDisabled =
      assay.eq
      (builtins.all (v: builtins.match "-calt|calt (off|=0)" v == null) (get "font-feature"))
      true;

    # The committed file carries no colour: a colour key or a hex literal appearing there
    # would be a second scheme author, competing with features/window-manager/stylix/palette.nix.
    paletteStaysNeutral = assay.eq (builtins.all (k: !(builtins.elem k colourKeys)) keys) true;
    noHexLiterals = assay.eq (builtins.all (v: builtins.match ".*#.*" v == null) values) true;

    # ...and the generated half is where the colour lives. 22 palette slots: 0-15 is the ANSI
    # palette every terminal program inherits, 16-21 the six base16 colours ANSI cannot hold.
    generatedSetsTwentyTwoPaletteSlots = assay.eq (builtins.length paletteSlots) 22;
    generatedPaletteIsInAnsiOrder =
      assay.eq (map (s: s.index) paletteSlots) (builtins.genList toString 22);
    generatedPaletteIsThePalette = assay.eq (map (s: s.color) paletteSlots) palette.ansi;
    generatedBackgroundIsBase00 = assay.eq (generatedGet "background") [palette.withHash.base00];
    generatedForegroundIsBase05 = assay.eq (generatedGet "foreground") [palette.withHash.base05];
    generatedSelectionIsVisible = assay.eq (generatedGet "selection-background") [palette.withHash.base02];
    # `theme` would load one of ghostty's bundled theme files, whose own palette would apply
    # alongside these keys -- two scheme authors again, just from the other direction.
    generatedSetsNoBundledTheme = assay.eq (generatedGet "theme") [];
    # Every colour emitted, including the eight non-palette keys, must be from the scheme.
    everyGeneratedColourIsFromThePalette =
      assay.eq
      (builtins.all
        (p:
          builtins.match "#.*" p.value
          == null
          || builtins.elem p.value (builtins.attrValues palette.withHash))
        (builtins.filter (p: p.key != "palette") generatedPairs))
      true;
    # The committed half must survive the concatenation intact.
    generatedConfigKeepsTheCommittedFile = assay.eq (lib.hasPrefix raw generatedConfig) true;
    generatedConfigKeepsTheFont = assay.eq (generatedGet "font-family") [stylixMonospace];

    # Presentation matched to alacritty.toml.
    opacityMatchesAlacritty = assay.eq (get "background-opacity") ["0.85"];
    paddingMatchesAlacritty = assay.eq (get "window-padding-x" ++ get "window-padding-y") ["8" "8"];
  }
