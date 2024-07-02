{
  pkgs,
  path,
  ...
}:
pkgs.stdenv.mkDerivation {
  name = "shfmt-check";
  dontBuild = true;
  src = path;
  doCheck = true;
  nativeBuildInputs = with pkgs; [shfmt];
  checkPhase = ''
    shfmt -d -s -i 2 -ci ${path}
  '';
  installPhase = ''
    mkdir "$out"
  '';
}
