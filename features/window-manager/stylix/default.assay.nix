# Colocated suite: stylix autoEnable, scheme selection and the font package.
let
  assay = import ./../../../common/assay/default.nix;
  palette = import ./palette.nix;
  # The stub stands in for nixpkgs so the module's attribute *shape* can be read without
  # instantiating anything. `nerd-fonts` is nested because that is how nixpkgs spells it
  # since the nerdfonts split -- a flat stub would let a regression back to a top-level
  # alias pass here unnoticed.
  #
  # `stdenv.mkDerivation` discards its argument and returns a plausible store path: the
  # schemes derivation is only ever interpolated into `base16Scheme`, so the suite needs its
  # *path shape*, not a build. Returning a path here is also what keeps this suite free of
  # the fetchFromGitHub it would otherwise drag in.
  pkgs = {
    noto-fonts-color-emoji = "emoji";
    nerd-fonts = {iosevka-term = "nerd-fonts.iosevka-term";};
    dejavu_fonts = "dejavu";
    stdenv.mkDerivation = _: "/nix/store/0000-tinted-theming-schemes";
  };
  mod = import ./default.nix {
    inherit pkgs;
    lib = (import <nixpkgs> {}).lib;
  };
  fonts = mod.stylix.fonts;

  # Comment lines are dropped before the alias tripwires below scan the file: the comment on
  # `monospace` names the broken alias in order to explain it, and a tripwire that cannot
  # tell prose from code would forbid documenting the bug it guards against.
  code =
    builtins.concatStringsSep "\n"
    (builtins.filter (l: builtins.match " *#.*" l == null)
      (builtins.filter builtins.isString
        (builtins.split "\n" (builtins.readFile ./default.nix))));
in
  assay.suite "stylix" {
    autoEnable = assay.eq mod.stylix.autoEnable true;
    polarityMatchesScheme = assay.eq mod.stylix.polarity palette.scheme.variant;

    # The scheme is selected by interpolating the slug into the pinned schemes derivation,
    # so the YAML stylix parses and the hex palette.nix carries describe one scheme.
    schemeFileNamesTheSlug =
      assay.eq
      (builtins.match ".*/share/schemes/${palette.scheme.slug}[.]yaml.*"
        mod.stylix.base16Scheme
        != null)
      true;

    # The monospace family is duplicated, deliberately and under test, into alacritty.toml
    # and ghostty's config (see ghostty/default.assay.nix). What is asserted here is the
    # half that used to be wrong: that `package` actually ships `name`.
    monospaceIsIosevkaTerm = assay.eq fonts.monospace.name "IosevkaTerm Nerd Font Mono";
    monospacePackageShipsThatFamily =
      assay.eq fonts.monospace.package "nerd-fonts.iosevka-term";
    # `pkgs.terminus-nerdfont` is a throwing alias, and Terminess rather than Iosevka.
    # Forcing it broke evaluation on every host; it must not return by either route.
    noThrowingFontAlias =
      assay.eq (builtins.match ".*pkgs[.]terminus-nerdfont.*" code != null) false;
    noNerdfontsMetapackage =
      assay.eq (builtins.match ".*pkgs[.]nerdfonts[^.-].*" code != null) false;
  }
