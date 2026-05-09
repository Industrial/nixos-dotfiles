# Terax upstream release (deb): https://github.com/crynta/terax-ai/releases
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  webkitgtk_4_1,
  gtk3,
  libsoup_3,
  cairo,
  gdk_pixbuf,
  glib,
}:
stdenv.mkDerivation rec {
  pname = "terax";
  version = "0.5.9";

  src = fetchurl {
    url = "https://github.com/crynta/terax-ai/releases/download/v${version}/Terax_${version}_amd64.deb";
    hash = "sha256-0mSHIdT9UHfryYMdxT3R2M+FOCjbX2oYLReBRFk78N4=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    libsoup_3
    cairo
    gdk_pixbuf
    glib
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r source/usr/* $out/
    runHook postInstall
  '';

  meta = {
    description = "Lightweight AI-native terminal (ADE) built with Tauri";
    homepage = "https://github.com/crynta/terax-ai";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
    platforms = ["x86_64-linux"];
    mainProgram = "terax";
  };
}
