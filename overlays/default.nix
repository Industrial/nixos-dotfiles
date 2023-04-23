{fetchFromGitHub}: final: prev: {
  overlay_lutris = prev.lutris.overrideAttrs (old: {
    src = final.fetchFromGitHub {
      owner = "NixOS";
      repo = "nixpkgs";
      rev = "b6388ae3ee77d7fd38dbcba94414fd735a9292e6";
      sha256 = "1gz13nk6j0c9ax9ckr5k2ljr2w6wlpb6v7pplz20sgdlvlwh6z49";
    };
  });

  overlay_promptr = prev.stdenv.mkDerivation {
    name = "promptr";
    src = prev.fetchFromGitHub {
      owner = "ferrislucas";
      repo = "promptr";
      rev = "v3.0.5";
      sha256 = "";
    };
    buildInputs = [prev.nodejs];
    installPhase = ''
      npm install --prefix $out $src
    '';
  };
}
