{
  nixpkgs,
  path,
  ...
}:
with import nixpkgs {system = "x86_64-linux";};
  stdenv.mkDerivation {
    name = "shfmt-check";
    dontBuild = true;
    src = path;
    doCheck = true;
    nativeBuildInputs = with nixpkgs; [shfmt];
    checkPhase = ''
      shfmt -d -s -i 2 -ci ${path}
    '';
    installPhase = ''
      mkdir "$out"
    '';
  }
