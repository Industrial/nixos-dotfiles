{fetchFromGitHub}: final: prev: {
  lutris = prev.lutris.override {
    name = "lutris";
    src = fetchFromGitHub {
      owner = "NixOS";
      repo = "nixpkgs";
      rev = "b6388ae3ee77d7fd38dbcba94414fd735a9292e6";
      sha256 = "1gz13nk6j0c9ax9ckr5k2ljr2w6wlpb6v7pplz20sgdlvlwh6z49";
    };
  };
}
