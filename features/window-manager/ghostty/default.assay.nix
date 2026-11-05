# Colocated suite: ghostty on systemPackages, plus the declared config.
let
  assay = import ./../../../common/assay/default.nix;
  # `writeTextFile = args: args.name` keeps the activation `.text` forceable
  # without a real nixpkgs: the stub must cover every pkgs attribute the text
  # interpolates, which here is writeTextFile and nothing else.
  settings = {
    hostname = "h";
    username = "alice";
    userdir = "/home/alice";
  };
  mkMod = writeTextFile:
    import ./default.nix {
      inherit settings;
      pkgs = {
        ghostty = "ghostty";
        inherit writeTextFile;
      };
    };
  mod = mkMod (args: args.name);
  activation = mod.system.activationScripts.linkGhosttyConfig.text;

  palette = import ./../stylix/palette.nix;

  # The file ghostty actually loads is the committed config plus a generated colour block.
  # Everything below named `committed*` is about the first half; the `generated*` cases are
  # about the second. Keeping them apart is what lets the neutrality tripwires survive: the
  # hand-written file must still carry no colour, because the only sanctioned way to change
  # the scheme is features/window-manager/stylix/palette.nix.
  generatedConfig =
    builtins.head
    (builtins.match ".*ln -sf (.*) /home/alice/[.]config/ghostty/config[.]ghostty\n"
      (mkMod (args: args.text)).system.activationScripts.linkGhosttyConfig.text);
  generatedPairs =
    map (l: let
      m = builtins.match " *([a-z0-9-]+) *= *(.*)" l;
    in {
      key = builtins.elemAt m 0;
      value = builtins.elemAt m 1;
    })
    (builtins.filter (l: builtins.match " *([#].*)?" l == null)
      (builtins.filter builtins.isString (builtins.split "\n" generatedConfig)));
  generatedGet = k: map (p: p.value) (builtins.filter (p: p.key == k) generatedPairs);
  # `palette = N=#rrggbb`, which ghostty accumulates rather than replaces.
  paletteSlots =
    map (v: let
      m = builtins.match "([0-9]+)=(#[0-9a-f]{6})" v;
    in {
      index = builtins.elemAt m 0;
      color = builtins.elemAt m 1;
    })
    (generatedGet "palette");

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
  #
  # The anchor is stylix's `monospaceName` let-binding rather than the `name =` inside its
  # `fonts.monospace` block: wave 7 gave the family a single binding there because fontconfig's
  # generic `monospace` alias is now written from the same value, and reading the binding is
  # what keeps this suite pointed at the one definition rather than one of its two uses.
  stylixMonospace =
    builtins.head
    (builtins.match ".*[\n]  monospaceName = \"([^\"]+)\";.*"
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

    # The committed file carries no colour. Wave 7 added the palette by *appending* a
    # generated block rather than editing this file, so these two tripwires are still live
    # and still mean what they meant: a colour key or a hex literal appearing here would be a
    # second scheme author, competing with features/window-manager/stylix/palette.nix.
    paletteStaysNeutral =
      assay.eq (builtins.all (k: !(builtins.elem k colourKeys)) keys) true;
    noHexLiterals =
      assay.eq (builtins.all (v: builtins.match ".*#.*" v == null) values) true;

    # ...and the generated half is where the colour lives. 22 palette slots: 0-15 is the ANSI
    # palette every terminal program inherits, 16-21 the six base16 colours ANSI cannot hold.
    generatedSetsTwentyTwoPaletteSlots = assay.eq (builtins.length paletteSlots) 22;
    generatedPaletteIsInAnsiOrder =
      assay.eq (map (s: s.index) paletteSlots)
      (builtins.genList toString 22);
    generatedPaletteIsThePalette =
      assay.eq (map (s: s.color) paletteSlots) palette.ansi;
    generatedBackgroundIsBase00 =
      assay.eq (generatedGet "background") [palette.withHash.base00];
    generatedForegroundIsBase05 =
      assay.eq (generatedGet "foreground") [palette.withHash.base05];
    generatedSelectionIsVisible =
      assay.eq (generatedGet "selection-background") [palette.withHash.base02];
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
        generatedPairs)
      true;
    # The committed half must survive the concatenation intact.
    generatedConfigKeepsTheFont =
      assay.eq (generatedGet "font-family") [stylixMonospace];

    # Presentation matched to alacritty.toml.
    opacityMatchesAlacritty = assay.eq (get "background-opacity") ["0.85"];
    paddingMatchesAlacritty =
      assay.eq (get "window-padding-x" ++ get "window-padding-y") ["8" "8"];
  }
