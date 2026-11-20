# Assay: stylix -- scheme selection, the colours stylix actually parses, and the fonts.
#
# The feature is evaluated together with stylix's own NixOS module (as profiles/desktop.nix
# imports it), so the claims read the real stylix.* options -- and `lib.stylix.colors`, the
# palette stylix parses out of the scheme YAML, which is what its targets paint with.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  palette = import ./palette.nix;
  cfg = nixos.eval {
    modules = [
      nixos.flakeInputs.stylix.nixosModules.stylix
      ./default.nix
    ];
  };
  stylix = cfg.stylix;
  fonts = stylix.fonts;
  parsed = cfg.lib.stylix.colors;
  baseNames = builtins.attrNames palette.colors;
in
  assay.suite "stylix" {
    autoEnable = assay.eq stylix.autoEnable true;
    polarityMatchesScheme = assay.eq stylix.polarity palette.scheme.variant;

    # The scheme is selected by interpolating palette.nix's slug into the pinned schemes
    # derivation, so the YAML stylix parses and the hex palette.nix carries describe one scheme.
    schemeFileNamesTheSlug =
      assay.eq (builtins.match "/nix/store/[^/]+-tinted-theming-schemes-[^/]+/share/schemes/(.*)" stylix.base16Scheme)
      ["${palette.scheme.slug}.yaml"];
    installsTheSchemes = assay.eq (nixos.hasPackage cfg "tinted-theming-schemes") true;
    # ...and what stylix parsed out of that YAML is palette.nix, digit for digit.
    stylixColoursAreThePalette =
      assay.eq (lib.genAttrs baseNames (n: lib.toLower parsed.${n})) palette.colors;

    # The monospace family is duplicated, deliberately and under test, into alacritty.toml
    # and ghostty's config (see ghostty/default.assay.nix). What is asserted here is the half
    # that used to be wrong: that `package` actually ships `name`.
    monospaceIsIosevkaTerm = assay.eq fonts.monospace.name "IosevkaTerm Nerd Font Mono";
    monospacePackageShipsThatFamily = assay.eq (lib.getName fonts.monospace.package) "nerd-fonts-iosevka-term";
    # `pkgs.terminus-nerdfont` was a throwing alias that only evaluated because nothing forced
    # it. Forcing every font package here is the tripwire: a throwing alias fails the suite.
    everyFontPackageEvaluates =
      assay.eq (map (f: builtins.isString fonts.${f}.package.drvPath) ["emoji" "monospace" "sansSerif" "serif"])
      [true true true true];
    sansAndSerifAreDejaVu =
      assay.eq [fonts.sansSerif.name fonts.serif.name] ["DejaVu Sans" "DejaVu Serif"];

    # stylix's fontconfig target is home-manager-only, so this feature writes the generic
    # monospace alias itself, as its single writer, from the same name.
    fontconfigMonospaceAliasIsTheFamily =
      assay.eq cfg.fonts.fontconfig.defaultFonts.monospace [fonts.monospace.name];
    wallpaperIsCommitted = assay.eq "${stylix.image}" "${./wallpaper.jpg}";
  }
