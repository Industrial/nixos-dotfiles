{
  nixpkgs,
  path,
  ...
}:
with import nixpkgs {system = "x86_64-linux";};
  stdenv.mkDerivation {
    name = "shellcheck-check";
    dontBuild = true;
    src = path;
    doCheck = true;
    nativeBuildInputs = with nixpkgs; [shellcheck];
    checkPhase = ''
      shellcheck -x ${path}/*
    '';
    installPhase = ''
      mkdir "$out"
    '';
  }
