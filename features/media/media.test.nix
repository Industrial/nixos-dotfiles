{pkgs, ...}: {
  calibre = import ./calibre/calibre.test.nix {inherit pkgs;};
  invidious = import ./invidious/invidious.test.nix {inherit pkgs;};
  jellyfin = import ./jellyfin/jellyfin.test.nix {inherit pkgs;};
  lidarr = import ./lidarr/lidarr.test.nix {inherit pkgs;};
  prowlarr = import ./prowlarr/prowlarr.test.nix {inherit pkgs;};
  qbittorrent = import ./qbittorrent/qbittorrent.test.nix {inherit pkgs;};
  radarr = import ./radarr/radarr.test.nix {inherit pkgs;};
  readarr = import ./readarr/readarr.test.nix {inherit pkgs;};
  sonarr = import ./sonarr/sonarr.test.nix {inherit pkgs;};
  spotify = import ./spotify/spotify.test.nix {inherit pkgs;};
  vlc = import ./vlc/vlc.test.nix {inherit pkgs;};
  whisparr = import ./whisparr/whisparr.test.nix {inherit pkgs;};
}
