# OmniRoute — unified AI gateway with free-tier routing and OpenAI-compatible API
# https://github.com/diegosouzapw/OmniRoute
{
  lib,
  stdenv,
  nodejs,
  fetchurl,
  makeWrapper,
  python3,
  node-gyp,
  sqlite,
}:
stdenv.mkDerivation rec {
  pname = "omniroute";
  version = "3.8.48";

  betterSqlite3Version = "12.11.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/omniroute/-/omniroute-${version}.tgz";
    hash = "sha256-sJXyyGId+zdaSRDtYkMOhz7abuuRm1ZU1AeyHFk4MlU=";
  };

  # OmniRoute ships a stripped better-sqlite3 (no binding.gyp); replace with the full crate.
  betterSqlite3Src = fetchurl {
    url = "https://registry.npmjs.org/better-sqlite3/-/better-sqlite3-${betterSqlite3Version}.tgz";
    hash = "sha256-6/Dtdaelnbyzsku9AU70nZ8VvDKOSty/UW8qj636KDU=";
  };

  sourceRoot = "package";

  nativeBuildInputs = [
    makeWrapper
    node-gyp
    python3
  ];
  buildInputs = [
    nodejs
    sqlite
    stdenv.cc
  ];

  buildPhase = ''
    runHook preBuild

    # OmniRoute bundles a stripped better-sqlite3; swap in the full crate before compiling.
    rm -rf dist/node_modules/better-sqlite3
    mkdir -p dist/node_modules/better-sqlite3
    tar -xzf ${betterSqlite3Src} -C dist/node_modules/better-sqlite3 --strip-components=1
    test -f dist/node_modules/better-sqlite3/binding.gyp

    export npm_config_nodedir=${nodejs}
    export npm_config_build_from_source=true
    export PATH="${lib.makeBinPath [nodejs node-gyp python3]}:$PATH"

    pushd dist/node_modules/better-sqlite3
    ${nodejs}/bin/npm run build-release
    popd

    runHook postBuild
  '';

  installPhase = ''
    mkdir -p "$out/lib/omniroute" "$out/bin"
    cp -r . "$out/lib/omniroute/"

    makeWrapper ${lib.getExe nodejs} "$out/bin/omniroute" \
      --set-default PORT "20128" \
      --set-default NODE_OPTIONS "--max-old-space-size=4096" \
      --set-default APP_LOG_TO_FILE "false" \
      --add-flags "$out/lib/omniroute/dist/server.js"

    makeWrapper ${lib.getExe nodejs} "$out/bin/omniroute-dashboard" \
      --set-default PORT "20128" \
      --set-default NODE_OPTIONS "--max-old-space-size=4096" \
      --set-default APP_LOG_TO_FILE "false" \
      --add-flags "$out/lib/omniroute/dist/server.js"
  '';

  meta = {
    description = "Unified AI router with multi-provider free-tier routing and OpenAI-compatible APIs";
    homepage = "https://github.com/diegosouzapw/OmniRoute";
    changelog = "https://github.com/diegosouzapw/OmniRoute/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = [];
    mainProgram = "omniroute";
    platforms = lib.platforms.linux;
  };
}
