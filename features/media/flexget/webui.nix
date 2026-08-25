# The FlexGet Web UI (Vue bundle) is not present in nixpkgs' flexget
# because that packaging builds from the GitHub source tarball, where
# ui/v2/dist only exists as a "run the npm build yourself" stub page.
# The PyPI wheel ships the prebuilt bundle; this derivation extracts it
# so services.flexget can serve a real UI.
{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:
stdenv.mkDerivation {
  pname = "flexget-webui";
  version = "3.20.5";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/5f/6a/01902617ebdaa3910400f459aee2e14ec830b9020e43ae9e75f4135b3903/flexget-3.20.5-py3-none-any.whl";
    hash = "sha256-SU1zAi4HBgd5QOZVkhCyf2+K/nnQd/ZE9WrUMkYKf+0=";
  };

  nativeBuildInputs = [unzip];
  sourceRoot = ".";
  unpackCmd = "${unzip}/bin/unzip -q $curSrc 'flexget/ui/v2/*' -d out";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share
    mv out/flexget/ui/v2 $out/share/webui
    runHook postInstall
  '';

  meta = with lib; {
    description = "Prebuilt FlexGet Web UI bundle extracted from the PyPI wheel";
    homepage = "https://flexget.com/Web-UI";
    license = licenses.mit;
  };
}
