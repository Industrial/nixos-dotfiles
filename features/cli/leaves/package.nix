{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "leaves";
  version = "0.2.0-cross";

  src = fetchFromGitHub {
    owner = "patonw";
    repo = "leaves";
    rev = "v${version}";
    hash = "sha256-JGWGo/JDC3/Sj97ca4CrgD4WaobYUVmbryuIg/AN2kU=";
  };

  cargoHash = "sha256-W1RWE08HXDhgejWcnUKI6/WTk9CAU6wayrNNl87rvMw=";

  meta = {
    description = "A text-mode disk usage treemap visualization utility";
    homepage = "https://github.com/patonw/leaves";
    license = lib.licenses.mpl20;
    mainProgram = "leaves";
    platforms = lib.platforms.linux;
  };
}
