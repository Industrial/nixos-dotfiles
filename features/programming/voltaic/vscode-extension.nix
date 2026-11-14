# Voltaic syntax highlighting, diagnostics, formatting and semantic tokens for
# Cursor/VSCode. Built from source (`editors/vscode/` in the voltaic repo), not
# from a marketplace — Voltaic is not published there.
#
# Two fields invert against the Emerald derivation beside this one, and both
# inversions are deliberate:
#
#   - `dontNpmBuild = true`. Voltaic's extension is plain JavaScript on purpose
#     (voltaic plan 49 §1.3: a TypeScript source would put a compile step
#     between a checkout and a working editor, for a file whose whole job is
#     to start a process). There is no `build` script to run.
#   - the install phase copies **`node_modules`**, not `dist`. This is the
#     fix for voltaic plan 71 §1.2's first defect: `src/extension.js` requires
#     `vscode-languageclient/node` at module top level, so an extension
#     installed without that closure throws before `activate` is entered and
#     silently degrades to TextMate highlighting alone — indistinguishable
#     from `voltaic.server.enable: false`.
{
  inputs,
  pkgs,
  ...
}:
pkgs.buildNpmPackage {
  pname = "vscode-voltaic-lang";
  version = "0.2.0";
  src = "${inputs.voltaic}/editors/vscode";

  # Real hash, from `prefetch-npm-deps editors/vscode/package-lock.json`. If
  # that lockfile changes, bump this to anything, let the build fail with
  # "got: sha256-…", and paste that in.
  npmDepsHash = "sha256-3slypAOmFcJqzRCLR7qXG/IW5q3FpT1not9U0AO+1Eg=";

  dontNpmBuild = true;

  # **Every directory the manifest declares has to be copied here**, and the
  # list grew at 0.1.1 without this derivation noticing. `package.json` now
  # contributes two `themes/` and a language `icon` out of `icons/`, so an
  # install that copies only `src syntaxes node_modules` leaves VSCode with
  # theme entries pointing at files that are not there. `README.md` is the
  # extension pane's description and is cheap to carry.
  installPhase = ''
    runHook preInstall
    dir=$out/share/vscode/extensions/voltaic-lang.voltaic
    mkdir -p "$dir"
    cp package.json language-configuration.json README.md "$dir/"
    cp -r src syntaxes themes icons node_modules "$dir/"
    runHook postInstall
  '';

  passthru = {
    vscodeExtUniqueId = "voltaic-lang.voltaic";
    vscodeExtPublisher = "voltaic-lang";
    vscodeExtName = "voltaic";
  };
}
