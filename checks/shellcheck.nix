{
  pkgs,
  path,
  ...
}:
pkgs.stdenv.mkDerivation {
  name = "shellcheck-check";
  dontBuild = true;
  src = path;
  doCheck = true;
  nativeBuildInputs = with pkgs; [shellcheck];
  checkPhase = ''
    shellcheck -x ${path}/*
  '';
  installPhase = ''
    mkdir "$out"
  '';
}
