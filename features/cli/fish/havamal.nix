{pkgs, ...}:
pkgs.fishPlugins.buildFishPlugin rec {
  pname = "Hávamál";
  version = "v0.3.1";

  src = pkgs.fetchFromGitHub {
    owner = "Industrial";
    repo = "havamal-bash";
    rev = version;
    sha256 = "sha256-jsSl/Ts2VFzyZJGHD/8/QU/gqzDxz6Bz0Ajtu4kKec8=";
  };

  buildPhase = ''
    mkdir -p $out/share/fish/stanzas
    cp -r $src/stanzas/* $out/share/fish/stanzas/
  '';

  meta = with pkgs.lib; {
    description = "Prints a random havamal stanza";
    homepage = "https://github.com/Industrial/havamal-bash";
    license = licenses.unlicense;
    maintainers = with maintainers; [Industrial];
  };
}
