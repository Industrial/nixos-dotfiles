# Colocated suite: alacritty on systemPackages, plus the generated config.
#
# The config on disk is the committed alacritty.toml with a generated [colors] section
# appended. Both halves are asserted, and separately: the committed half must stay free of
# colour (so the scheme cannot be forked by hand-editing it), and the generated half must be
# the shared palette and nothing else.
let
  assay = import ./../../../common/assay/default.nix;
  palette = import ./../stylix/palette.nix;
  settings = {
    hostname = "h";
    username = "alice";
  };
  # The module is instantiated twice against the same settings: `args: args.name` keeps the
  # activation line assertable, `args: args.text` hands back the generated TOML, which is
  # the only way to assert on what it says. features/cli/zellij's suite does the same.
  mkMod = writeTextFile:
    import ./default.nix {
      inherit settings;
      pkgs = {
        alacritty = "alacritty";
        inherit writeTextFile;
      };
    };
  mod = mkMod (args: args.name);
  activation = mod.system.activationScripts.linkFile.text;

  generated = (mkMod (args: args.text)).system.activationScripts.linkFile.text;
  # fromTOML doubles as the parse check: a malformed generated section fails the suite at
  # eval rather than silently at the next alacritty launch. The activation text is
  # `mkdir -p ...\nln -sf <toml> /home/alice/...`, so the TOML is what sits between.
  tomlText =
    builtins.head
    (builtins.match ".*ln -sf (.*) /home/alice/[.]config/alacritty/alacritty[.]toml\n" generated);
  cfg = builtins.fromTOML tomlText;

  committed = builtins.fromTOML (builtins.readFile ./.config/alacritty/alacritty.toml);

  # builtins has no sublist, and pulling nixpkgs' lib in for one slice would give this suite
  # a fixture it otherwise does not need.
  slice = start: count: list: builtins.genList (i: builtins.elemAt list (start + i)) count;

  named = block: [
    block.black
    block.red
    block.green
    block.yellow
    block.blue
    block.magenta
    block.cyan
    block.white
  ];
  # Slots 0-15 in ANSI order, which is what every terminal program inherits.
  ansiSlots = named cfg.colors.normal ++ named cfg.colors.bright;
  indexed = map (e: e.color) cfg.colors.indexed_colors;
  allEmitted =
    ansiSlots
    ++ indexed
    ++ builtins.attrValues cfg.colors.primary
    ++ builtins.attrValues cfg.colors.cursor
    ++ builtins.attrValues cfg.colors.selection;
in
  assay.suite "alacritty" {
    packages = assay.eq mod.environment.systemPackages ["alacritty"];
    activationLinksTheGeneratedConfig =
      assay.eq
      (builtins.match ".*ln -sf alacritty[.]toml /home/alice/[.]config/alacritty/alacritty[.]toml.*"
        activation
        != null)
      true;

    # The committed file stays presentation-only. This is the same guard ghostty's suite
    # carries, and it still means something now that colour is generated: the only way to
    # change the scheme is features/window-manager/stylix/palette.nix.
    committedTomlHasNoColours = assay.eq (committed ? colors) false;
    committedTomlKeepsTheFont =
      assay.eq committed.font.normal.family "IosevkaTerm Nerd Font Mono";

    generatedTomlParses = assay.eq (builtins.isAttrs cfg) true;
    # Not vacuous: 16 ANSI slots plus the 6 indexed ones base16 defines.
    everyAnsiSlotIsSet = assay.eq (builtins.length ansiSlots) 16;
    sixIndexedColours = assay.eq (builtins.length indexed) 6;
    indexedColoursAreSixteenToTwentyOne =
      assay.eq (map (e: e.index) cfg.colors.indexed_colors) [16 17 18 19 20 21];

    # The whole point: these sixteen values are the ANSI palette starship, bat, fzf, delta
    # and btop all resolve their named colours through, so they must be the scheme's.
    ansiSlotsAreThePaletteInOrder =
      assay.eq ansiSlots (slice 0 16 palette.ansi);
    indexedColoursAreThePalette =
      assay.eq indexed (slice 16 6 palette.ansi);
    everyColourIsFromThePalette =
      assay.eq
      (builtins.all (v: builtins.elem v (builtins.attrValues palette.withHash)) allEmitted)
      true;

    backgroundIsBase00 =
      assay.eq cfg.colors.primary.background palette.withHash.base00;
    foregroundIsBase05 =
      assay.eq cfg.colors.primary.foreground palette.withHash.base05;
    selectionIsVisibleAgainstBackground =
      assay.eq (cfg.colors.selection.background != cfg.colors.primary.background) true;
    # Alacritty computes `dim` from `normal` when absent, and base16 specifies no dim range,
    # so inventing one here would be six colours the scheme does not contain.
    noInventedDimRange = assay.eq (cfg.colors ? dim) false;
  }
