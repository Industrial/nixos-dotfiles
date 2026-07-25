# OmniRoute — unified AI gateway with free-tier routing and OpenAI-compatible API
# https://github.com/diegosouzapw/OmniRoute
{
  lib,
  stdenv,
  nodejs,
  fetchurl,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "omniroute";
  version = "3.8.48";

  src = fetchurl {
    url = "https://registry.npmjs.org/omniroute/-/omniroute-${version}.tgz";
    hash = "sha256-sJXyyGId+zdaSRDtYkMOhz7abuuRm1ZU1AeyHFk4MlU=";
  };

  sourceRoot = "package";

  nativeBuildInputs = [makeWrapper];
  buildInputs = [nodejs];

  dontBuild = true;

  installPhase = ''
    mkdir -p "$out/lib/omniroute" "$out/bin"
    cp -r . "$out/lib/omniroute/"

    # The published npm CLI expects a full `npm install` (node_modules at package root).
    # The prebuilt Next.js server in dist/server.js is self-contained and is the supported
    # headless entry point for Nix/systemd deployments.
    makeWrapper ${lib.getExe nodejs} "$out/bin/omniroute" \
      --add-flags "$out/lib/omniroute/dist/server.js"

    makeWrapper ${lib.getExe nodejs} "$out/bin/omniroute-dashboard" \
      --set-default PORT "20128" \
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
