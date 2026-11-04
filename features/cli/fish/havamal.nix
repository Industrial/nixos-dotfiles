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

  # `buildFishPlugin`'s installPhase only installs completions/, functions/, conf/ and conf.d/.
  # `stanzas/` is ours to place. The conf.d entry is installed explicitly too, so the path
  # `features/cli/fish/default.nix` sources is created by this derivation rather than by an
  # upstream convention — a rename upstream then fails the build instead of erroring on every
  # interactive fish start.
  buildPhase = ''
    mkdir -p $out/share/fish/stanzas $out/share/fish/vendor_conf.d
    cp -r $src/stanzas/* $out/share/fish/stanzas/
    install -m644 $src/conf.d/Hávamál.fish $out/share/fish/vendor_conf.d/Hávamál.fish
  '';

  meta = with pkgs.lib; {
    description = "Prints a random havamal stanza";
    homepage = "https://github.com/Industrial/havamal-bash";
    license = licenses.unlicense;
    maintainers = with maintainers; [Industrial];
  };
}
