{pkgs, ...}:
let
  base16-shell = pkgs.stdenv.mkDerivation rec {
    pname = "base16-shell";
    version = "main";
    src = pkgs.fetchFromGitHub {
      owner = "tinted-theming";
      repo = pname;
      rev = "d0737249d4c8bb26dc047ea9fba0054ae7024c04";
      sha256 = "sha256-X6Pcu/LM9PSaUwLxHoklXNkSEz+X1+cIt8lmu6tViMk=";
    };
    # buildInputs = [ pkgs.base16-builder ];
    installPhase = ''
      mkdir -p $out/share/base16/shell
      cp -r scripts $out/share/base16/shell
    '';
  };
in
{
  home.packages = [
    base16-shell
  ];
}