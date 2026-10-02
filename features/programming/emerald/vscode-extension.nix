# Emerald syntax highlighting + live diagnostics (emerald-lsp) for
# Cursor/VSCode. Built from source (editors/vscode/ in the emerald repo),
# not from a marketplace — Emerald isn't published there.
{
  inputs,
  pkgs,
  ...
}:
pkgs.buildNpmPackage {
  pname = "vscode-emerald-lang";
  version = "0.1.0";
  src = "${inputs.emerald}/editors/vscode";

  nativeBuildInputs = with pkgs; [
    pkg-config
    python3
  ];

  buildInputs = with pkgs; [
    libsecret
  ];

  # Real hash, from a real build of this exact source in a throwaway
  # sandbox. If editors/vscode/package.json or package-lock.json ever
  # change, this will need updating the usual way: bump it to anything,
  # let the build fail with "got: sha256-...", paste that in.
  npmDepsHash = "sha256-yySxi9z6n4xdGuE54cdM58Yt/tKGo4gCwhgl559V/8Q=";

  dontNpmBuild = false;
  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall
    dir=$out/share/vscode/extensions/emerald-lang.emerald-lang
    mkdir -p "$dir"
    cp -r dist "$dir/"
    cp package.json language-configuration.json "$dir/"
    cp -r syntaxes "$dir/"
    runHook postInstall
  '';

  passthru = {
    vscodeExtUniqueId = "emerald-lang.emerald-lang";
    vscodeExtPublisher = "emerald-lang";
    vscodeExtName = "emerald-lang";
  };
}
