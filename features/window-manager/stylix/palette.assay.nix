# Colocated suite for features/window-manager/stylix/palette.nix
#
# palette.nix is a hand-written projection of upstream YAML, so the thing worth testing is not
# that it parses but that it still agrees with its source. This suite reads
# gruvbox-dark-hard.yaml out of the commit-pinned tinted-theming/schemes derivation and
# compares every field. That read is import-from-derivation, which is exactly why it lives
# here instead of in palette.nix: a suite may force a derivation, a host eval may not.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;

  palette = import ./palette.nix;
  schemes =
    (import ./derivations/tinted-theming-schemes.nix {inherit pkgs lib;})
    .tinted-theming-schemes;
  yaml = builtins.readFile "${schemes}/share/schemes/${palette.scheme.slug}.yaml";

  # The base16 scheme files are a flat, fully-quoted subset of YAML: `key: "value"` at column
  # zero, then a `palette:` block of `  baseNN: "rrggbb"` with an optional trailing `# name`
  # comment. That is narrow enough to match per key, and a key that stops matching yields
  # `null` here rather than a wrong answer -- which fails the comparison below loudly.
  topLevel = key: let
    m = builtins.match ".*\n?${key}: \"([^\"]*)\".*" yaml;
  in
    if m == null
    then null
    else builtins.head m;

  upstreamColor = name: let
    m = builtins.match ".*\n  ${name}: \"([0-9a-fA-F]{6})\".*" yaml;
  in
    if m == null
    then null
    else builtins.head m;

  baseNames = builtins.attrNames palette.colors;
  upstreamColors =
    builtins.listToAttrs
    (map (n: {
        name = n;
        value = upstreamColor n;
      })
      baseNames);

  # The pin itself: palette.nix records the rev it was projected from, and the derivation
  # records the rev actually fetched. If someone bumps one, this is what notices.
  derivationRev =
    builtins.head
    (builtins.match ".*rev = \"([0-9a-f]{40})\";.*"
      (builtins.readFile ./derivations/tinted-theming-schemes.nix));

  # stylix/default.nix must select its scheme from this file rather than restating the slug,
  # so there is exactly one place the fleet's scheme is named.
  moduleDefersToPalette =
    builtins.match ".*theme = palette[.]scheme[.]slug;.*"
    (builtins.readFile ./default.nix)
    != null;
in
  assay.suite "stylix-palette" {
    # Every one of the sixteen, compared as a whole attrset so a single wrong digit names
    # itself in the diff instead of hiding behind a boolean.
    coloursMatchUpstream = assay.eq palette.colors upstreamColors;
    sixteenColours = assay.eq (builtins.length baseNames) 16;

    nameMatchesUpstream = assay.eq palette.scheme.name (topLevel "name");
    systemMatchesUpstream = assay.eq palette.scheme.system (topLevel "system");
    variantMatchesUpstream = assay.eq palette.scheme.variant (topLevel "variant");

    pinMatchesDerivation = assay.eq palette.scheme.sourceRev derivationRev;
    moduleSelectsThisScheme = assay.eq moduleDefersToPalette true;

    # withHash is what every consumer actually interpolates; a missing `#` is a config file
    # that parses and renders the wrong colour.
    withHashIsPrefixed =
      assay.eq
      (builtins.all (n: palette.withHash.${n} == "#${palette.colors.${n}}") baseNames)
      true;

    # 0-15 are the ANSI slots; 16-21 carry the six base16 colours ANSI cannot hold.
    ansiHasTwentyTwoSlots = assay.eq (builtins.length palette.ansi) 22;
    ansiNamesResolve =
      assay.eq (builtins.all (n: palette.colors ? ${n}) palette.ansiNames) true;
    # Background and foreground must land where every terminal expects them.
    ansiBlackIsBackground =
      assay.eq (builtins.elemAt palette.ansi 0) palette.withHash.base00;
    ansiWhiteIsForeground =
      assay.eq (builtins.elemAt palette.ansi 7) palette.withHash.base05;
    # The specified base16 quirk: the bright range repeats the accents.
    brightRepeatsNormalAccents =
      assay.eq
      (map (i: builtins.elemAt palette.ansi i) [9 10 11 12 13 14])
      (map (i: builtins.elemAt palette.ansi i) [1 2 3 4 5 6]);
  }
