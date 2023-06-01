{pkgs, ...}: let
  ruby = pkgs.ruby.overrideAttrs (attrs: {
    version = "3.2.2";
    src = pkgs.fetchurl {
      url = "https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.2.tar.gz";
      sha256 = "sha256-lsV1WIcaZ0jeW8nydOk/S1qtBs2PN776Do2U57ikI7w=";
    };
    patches = [];
    postPatch = "";
  });
in {
  home.packages = [
    ruby
  ];
}
