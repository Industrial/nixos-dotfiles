let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./languages-javascript.nix {};
  on = h.feature ./languages-javascript.nix {local.features.languages-javascript.enable = true;};
  # The projection in feature-eval.nix does not carry package attrs, so reach into
  # the evaluated config directly for the Bun pin.
  onConfig = (h.evalModule ./languages-javascript.nix {local.features.languages-javascript.enable = true;}).config;
in
  assay.suite "languages-javascript" {
    disabled = assay.eq off.languages.javascript.enable false;
    enabled = assay.eq on.languages.javascript.enable true;
    bunEnabled = assay.eq on.languages.javascript.bunEnable true;
    typescriptEnabled = assay.eq on.languages.typescriptEnable true;
    bunPinnedVersion = assay.eq onConfig.languages.javascript.bun.package.version "1.4.0";
    bunPackageOverridesNixpkgs =
      assay.eq (onConfig.languages.javascript.bun.package.pname or "") "bun";
  }
