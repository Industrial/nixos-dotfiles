# Redox syntax highlighting, diagnostics, formatting and semantic tokens for
# Cursor/VSCode. Built from source (`editors/vscode/` in the redox repo), not
# from a marketplace — Redox is not published there.
#
# Two fields invert against the Emerald derivation beside this one, and both
# inversions are deliberate:
#
#   - `dontNpmBuild = true`. Redox's extension is plain JavaScript on purpose
#     (redox plan 49 §1.3: a TypeScript source would put a compile step
#     between a checkout and a working editor, for a file whose whole job is
#     to start a process). There is no `build` script to run.
#   - the install phase copies **`node_modules`**, not `dist`. This is the
#     fix for redox plan 71 §1.2's first defect: `src/extension.js` requires
#     `vscode-languageclient/node` at module top level, so an extension
#     installed without that closure throws before `activate` is entered and
#     silently degrades to TextMate highlighting alone — indistinguishable
#     from `redox.server.enable: false`.
{
  inputs,
  pkgs,
  ...
}:
pkgs.buildNpmPackage {
  pname = "vscode-redox-lang";
  version = "0.1.0";
  src = "${inputs.redox}/editors/vscode";

  # Real hash, from `prefetch-npm-deps editors/vscode/package-lock.json`. If
  # that lockfile changes, bump this to anything, let the build fail with
  # "got: sha256-…", and paste that in.
  npmDepsHash = "sha256-WhyyboeEswhnEisJnt4YQDcZi4jKYQrpzma8oJf1FGw=";

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    dir=$out/share/vscode/extensions/redox-lang.redox
    mkdir -p "$dir"
    cp package.json language-configuration.json "$dir/"
    cp -r src syntaxes node_modules "$dir/"
    runHook postInstall
  '';

  passthru = {
    vscodeExtUniqueId = "redox-lang.redox";
    vscodeExtPublisher = "redox-lang";
    vscodeExtName = "redox";
  };
}
